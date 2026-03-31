#!/bin/bash -l
#SBATCH --job-name=vmgcTax_v2
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=01:00:00
#SBATCH --mem=8G
#SBATCH --cpus-per-task=1
#SBATCH -p msc_appbio

set -euo pipefail

#Location

PROJECT="/scratch/prj/rosetree/Valentina"
IN_DIR="${PROJECT}/databases/VMGC_DB"

# VMGC metadata tables
FUNG_INFO="${IN_DIR}/VMGC_eukaryocyte.info"
VIR_INFO="${IN_DIR}/VMGC_virus.info"

# Outputs
OUT_FASTA_DIR="${PROJECT}/databases/VMGC_DB/VMGC_DB_taxid_fastas"
TAX_DIR="${PROJECT}/databases/VMGC_DB/VMGC_custom_taxonomy"

mkdir -p "${OUT_FASTA_DIR}" "${TAX_DIR}"

# Print as we go along
echo "[INFO] Input FASTA dir: ${IN_DIR}"
echo "[INFO] Fungal info:     ${FUNG_INFO}"
echo "[INFO] Viral info:      ${VIR_INFO}"
echo "[INFO] Output FASTAs:   ${OUT_FASTA_DIR}"
echo "[INFO] Taxonomy dir:    ${TAX_DIR}"

# Basic checks, making sure info exists
[[ -f "${FUNG_INFO}" ]] || { echo "[ERROR] Missing ${FUNG_INFO}"; exit 1; }
[[ -f "${VIR_INFO}"  ]] || { echo "[ERROR] Missing ${VIR_INFO}"; exit 1; }

# Building the taxonomy + rewrite FASTA headers using a Python script---------------------
python3 - << 'PY'
import os, re, csv, sys
from pathlib import Path

# Same folder locations as above
PROJECT = "/scratch/prj/rosetree/Valentina"
IN_DIR = Path(PROJECT) / "databases/VMGC_DB"
FUNG_INFO = IN_DIR / "VMGC_eukaryocyte.info"
VIR_INFO  = IN_DIR / "VMGC_virus.info"
OUT_FASTA_DIR = Path(PROJECT) / "databases/VMGC_DB/VMGC_DB_taxid_fastas"
TAX_DIR = Path(PROJECT) / "databases/VMGC_DB/VMGC_custom_taxonomy"

OUT_FASTA_DIR.mkdir(parents=True, exist_ok=True)
TAX_DIR.mkdir(parents=True, exist_ok=True)

# Files for Kraken 
NODES = TAX_DIR / "nodes.dmp"
NAMES = TAX_DIR / "names.dmp"

#Mapping files
MAP_LEAF = TAX_DIR / "vmgc_leafname_to_taxid.tsv"     # FASTA basename -> leaf taxid
MAP_VOTU = TAX_DIR / "virus_contig_to_votu.tsv"        # contig id -> vOTU_ID
MAP_FUNG = TAX_DIR / "fungus_genome_to_lineage.tsv"    # Genome_ID -> taxonomy string + cluster

# -----------------------------
# Helper functions to write Kraken/NCBI-style taxonomy files
# -----------------------------
def write_node(fp, taxid, parent, rank):
    # Minimal nodes.dmp format Kraken accepts: tax_id | parent_tax_id | rank | ...
    fp.write(f"{taxid}\t|\t{parent}\t|\t{rank}\t|\t-\t|\t-\t|\t0\t|\t0\t|\t0\t|\t0\t|\t0\t|\t0\t|\t0\t|\t\n")
    # names.dmp: taxid -> name
def write_name(fp, taxid, name, name_class="scientific name"):
    fp.write(f"{taxid}\t|\t{name}\t|\t\t|\t{name_class}\t|\n")

# -----------------------------
# Allocate taxids safely: invent taxids in a “safe” high range that won’t collide with real NCBI taxids
# -----------------------------
START = 900000001
taxid_counter = START

def new_taxid():
    global taxid_counter
    tid = taxid_counter
    taxid_counter += 1
    return tid

#--------------------------
# Data structures to build a taxonomy without duplicates
#------------------------
node_taxid = {}
nodes = {}
names = {}

def ensure_node(key, parent_taxid, rank, display_name):
    """
    Create a taxonomy node once. Return its taxid.
    key must uniquely define the node (e.g., "fungi|p_Ascomycota" or "virus|vOTU|v0007").
    """
    if key in node_taxid:
        return node_taxid[key]
    tid = new_taxid()
    node_taxid[key] = tid
    nodes[tid] = (parent_taxid, rank)
    names[tid] = display_name
    return tid

# -----------------------------
# Create top-level roots main branches:
#      VMGC_Fungi
#      VMGC_Viruses
#      Uknown
# -----------------------------
VMGC_FUNGI = ensure_node("VMGC|Fungi", 1, "superkingdom", "VMGC_Fungi")
VMGC_VIRUS = ensure_node("VMGC|Viruses", 1, "superkingdom", "VMGC_Viruses")
VMGC_UNKNOWN = ensure_node("VMGC|Unknown", 1, "no rank",      "VMGC_Unknown")

# For viruses create unclassified and missing family info
VIR_FAM_UNK = ensure_node("virus|family|Unclassified", VMGC_VIRUS, "family", "Unclassified")

# -----------------------------
# Building taxonomy tree for fungi
# -----------------------------
fung_rows = []
with FUNG_INFO.open() as f:
    reader = csv.DictReader(f, delimiter="\t")
    required = {"Genome_ID", "Taxonomic_assignment", "Cluster"}
    missing = required - set(reader.fieldnames or [])
    if missing:
        print(f"[ERROR] Missing columns in fungal info: {missing}", file=sys.stderr)
        sys.exit(1)
    for row in reader:
        if not row["Genome_ID"].strip():
            continue
        fung_rows.append(row)

# Converting VMGC taxonomy string prefixes like p_, c_, f_,to Kraken-like rank names
RANK_MAP = {
    "p": "phylum",
    "sp": "subphylum",  
    "c": "class",
    "o": "order",
    "f": "family",
    "g": "genus",
    "s": "species"
}

fung_genome_to_species_taxid = {}

# Write fungus mapping 
with MAP_FUNG.open("w") as mf:
    mf.write("Genome_ID\tTaxonomic_assignment\tCluster\n")
    for row in fung_rows:
        genome = row["Genome_ID"].strip()
        lineage = row["Taxonomic_assignment"].strip()
        cluster = row["Cluster"].strip()
        mf.write(f"{genome}\t{lineage}\t{cluster}\n")

        # If taxonomy string missing
        if not lineage:
            sp_tid = ensure_node(f"fungi|species|UNKNOWN|{genome}", VMGC_FUNGI, "species", f"UNKNOWN_species_for_{genome}")
            fung_genome_to_species_taxid[genome] = sp_tid
            continue

        # Build lineage path under VMGC_FUNGI
        parent = VMGC_FUNGI
        parts = [p for p in lineage.split(";") if p]
        for part in parts:
            m = re.match(r"^(p|sp|c|o|f|g|s)_(.+)$", part)
            if not m:
                # If something unexpected occurs, store as no-rank node
                key = f"fungi|norank|{part}"
                parent = ensure_node(key, parent, "no rank", part)
                continue
            prefix, label = m.group(1), m.group(2)
            rank = RANK_MAP.get(prefix, "no rank")
            # Key includes prefix+label so it's unique across levels
            key = f"fungi|{prefix}|{label}"
            parent = ensure_node(key, parent, rank, label)

        # After loop, 'parent' is the species node taxid (or deepest node)
        fung_genome_to_species_taxid[genome] = parent

# -----------------------------
# Create viral taxonomy tree: family -> vOTU -> contigs
# -----------------------------
vir_rows = []
with VIR_INFO.open() as f:
    reader = csv.DictReader(f, delimiter="\t")
    required = {"vOTU_ID", "Taxonomic_classification_(family_level)", "viral_sequences"}
    missing = required - set(reader.fieldnames or [])
    if missing:
        print(f"[ERROR] Missing columns in viral info: {missing}", file=sys.stderr)
        sys.exit(1)
    for row in reader:
        if not row["vOTU_ID"].strip():
            continue
        vir_rows.append(row)

# contig -> vOTU mapping
contig_to_votu = {}

for row in vir_rows:
    votu = row["vOTU_ID"].strip()
    fam = row["Taxonomic_classification_(family_level)"].strip() or "Unclassified"
    seqs = row["viral_sequences"].strip()

    # family node
    if fam == "Unclassified":
        fam_tid = VIR_FAM_UNK
    else:
        fam_tid = ensure_node(f"virus|family|{fam}", VMGC_VIRUS, "family", fam)

    # vOTU node under family
    votu_tid = ensure_node(f"virus|vOTU|{votu}", fam_tid, "species", votu)

    if seqs:
        for contig in [s.strip() for s in seqs.split(",") if s.strip()]:
            contig_to_votu[contig] = (votu, votu_tid)

# Save contig->vOTU mapping table 
with MAP_VOTU.open("w") as mv:
    mv.write("contig_id\tvOTU_ID\n")
    for contig, (votu, _) in sorted(contig_to_votu.items()):
        mv.write(f"{contig}\t{votu}\n")

# -----------------------------
# Processing FASTA files:
# Rewrite every FASTA in IN_DIR individually and choose parent based on:
#       - if basename matches fungal Genome_ID -> fungal lineage parent
#       - else if sequences inside match viral contig IDs -> assign per sequence header
#       - else: place under VMGC_VIRUS "unclassified" bucket or VMGC_FUNGI directly
# -----------------------------

def rewrite_fasta_file(in_path: Path, out_path: Path, default_parent_tid: int, default_leaf_name: str):
    """
    Rewrite a FASTA and append |kraken:taxid|<leaf_taxid> to each header.
    For multi-fasta: each record gets same leaf taxid (this is correct only if file contains one genome).
    """
    leaf_tid = ensure_node(f"leaf|{default_leaf_name}", default_parent_tid, "strain", default_leaf_name)
    with in_path.open() as fin, out_path.open("w") as fout:
        for line in fin:
            if line.startswith(">"):
                hdr = line[1:].strip()
                fout.write(f">{hdr}|kraken:taxid|{leaf_tid}\n")
            else:
                fout.write(line)
    return leaf_tid

leaf_map = [] 

# Identify per-file FASTAs 
fasta_files = sorted([p for p in IN_DIR.iterdir() if p.is_file() and p.suffix in (".fa", ".fna", ".fasta")])

if not fasta_files:
    print(f"[ERROR] No FASTA files found in {IN_DIR}", file=sys.stderr)
    sys.exit(1)

for fp in fasta_files:
    base = fp.name
    stem = fp.stem  

    out_fp = OUT_FASTA_DIR / f"{stem}.fa"

    # Fungal single-genome FASTA
    if stem in fung_genome_to_species_taxid:
        parent_tid = fung_genome_to_species_taxid[stem]
        leaf_tid = rewrite_fasta_file(fp, out_fp, parent_tid, stem)
        leaf_map.append((stem, leaf_tid))
        continue

    # Viral multi-FASTA 
    # Detect if file contains headers matching known contig IDs and assign each contig to its vOTU leaf.
    if stem.startswith("VMGC_virus") or stem.startswith("VP_") or "virus" in stem.lower():
        with fp.open() as fin, out_fp.open("w") as fout:
            current_tid = None
            for line in fin:
                if line.startswith(">"):
                    hdr = line[1:].strip()
                    # contig id is often the first token up to whitespace
                    contig_id = hdr.split()[0]
                    if contig_id in contig_to_votu:
                        votu, votu_tid = contig_to_votu[contig_id]
                        # create leaf under vOTU
                        current_tid = ensure_node(f"virus|leaf|{contig_id}", votu_tid, "strain", contig_id)
                    else:
                        # unknown viral contig -> put under Unclassified family bucket via a dummy vOTU "vOTU_UNKNOWN"
                        votu_tid = ensure_node("virus|vOTU|UNKNOWN", VIR_FAM_UNK, "species", "vOTU_UNKNOWN")
                        current_tid = ensure_node(f"virus|leaf|{contig_id}", votu_tid, "strain", contig_id)

                    fout.write(f">{hdr}|kraken:taxid|{current_tid}\n")
                else:
                    fout.write(line)
        leaf_map.append((stem, -1))
        continue

    # Unknown file -> attach under VMGC_UKNOWN
    parent_tid = VMGC_UNKNOWN
    leaf_tid = rewrite_fasta_file(fp, out_fp, parent_tid, stem)
    leaf_map.append((stem, leaf_tid))
# -----------------------------
# Write taxonomy files: nodes and names
# -----------------------------
with NODES.open("w") as fnodes:
    fnodes.write("1\t|\t1\t|\tno rank\t|\t-\t|\t-\t|\t0\t|\t0\t|\t0\t|\t0\t|\t0\t|\t0\t|\t0\t|\t\n")
    for tid, (parent, rank) in sorted(nodes.items()):
        write_node(fnodes, tid, parent, rank)

with NAMES.open("w") as fnames:
    fnames.write("1\t|\troot\t|\t\t|\tscientific name\t|\n")
    for tid, nm in sorted(names.items()):
        write_name(fnames, tid, nm)

# Write leaf map 
with MAP_LEAF.open("w") as fml:
    fml.write("leaf_name\tleaf_taxid\n")
    for stem, tid in leaf_map:
        fml.write(f"{stem}\t{tid}\n")

print("[INFO] Done building taxonomy + rewriting FASTAs")
print(f"[INFO] nodes.dmp: {NODES}")
print(f"[INFO] names.dmp: {NAMES}")
print(f"[INFO] leaf map:  {MAP_LEAF}")
print(f"[INFO] output FASTAs in: {OUT_FASTA_DIR}")
PY

echo "[INFO] Finished taxonomy build job."
echo "[INFO] Quick check:"
echo " - taxonomy files:"
ls -lh "${TAX_DIR}/nodes.dmp" "${TAX_DIR}/names.dmp" | cat
echo " - rewritten FASTA count:"
find "${OUT_FASTA_DIR}" -maxdepth 1 -type f -name "*.fa" | wc -l
