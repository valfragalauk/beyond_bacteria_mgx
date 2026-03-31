#!/usr/bin/env python3

"""
Annotate taxonomy IDs using NCBI nodes.dmp to determine whether each taxon
belongs to Viruses , Fungi , or Other.
"""

import argparse
from pathlib import Path


def load_nodes(nodes_file):
    """
    Get parent taxid
    """
    parent = {}

    with open(nodes_file) as f:
        for line in f:
            parts = line.strip().split("\t|\t")
            taxid = parts[0]
            parent_taxid = parts[1]
            parent[taxid] = parent_taxid

    return parent

"""
Determine lineage
"""

def get_lineage(taxid, parent_dict):
    lineage = []
    current = taxid

    while current in parent_dict:
        lineage.append(current)
        if current == parent_dict[current]:  # root
            break
        current = parent_dict[current]

    return lineage


def classify_taxon(lineage):
    """
    Determine category based on lineage
    """
    if "10239" in lineage:
        return "Virus"
    elif "4751" in lineage:
        return "Fungi"
    else:
        return "Other"


def main():
    parser = argparse.ArgumentParser(description="Annotate taxonomy IDs as Virus, Fungi, or Other")
    parser.add_argument("--taxids", required=True, help="File with taxonomy IDs")
    parser.add_argument("--nodes", required=True, help="nodes.dmp file")
    parser.add_argument("--output", required=True, help="Output annotation file")
    args = parser.parse_args()

    parent_dict = load_nodes(args.nodes)

    output_lines = []

    with open(args.taxids) as f:
        for line in f:
            taxid = line.strip()

            if taxid not in parent_dict:
                category = "Unknown"
            else:
                lineage = get_lineage(taxid, parent_dict)
                category = classify_taxon(lineage)

            output_lines.append(f"{taxid}\t{category}")

    with open(args.output, "w") as out:
        out.write("taxonomy_id\tcategory\n")
        out.write("\n".join(output_lines))

    print(f"Saved taxonomy annotation to: {args.output}")


if __name__ == "__main__":
    main()
