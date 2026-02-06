#!/usr/bin/env python3
"""
Making a small synthetic FASTQ from FASTA genomes downloaded from the kraken tutorial given that our real data is in fastq form to do the testing of Kraken2/Bracken without using real cohort data.

It samples random 150bp fragments and assigns constant high quality scores.
"""

import random
import sys
from pathlib import Path

def read_fasta(path: Path):
    """Yield (header, sequence) from a FASTA file."""
    header = None
    seq_chunks = []
    with path.open() as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            if line.startswith(">"):
                if header is not None:
                    yield header, "".join(seq_chunks).upper()
                header = line[1:].split()[0]
                seq_chunks = []
            else:
                seq_chunks.append(line)
        if header is not None:
            yield header, "".join(seq_chunks).upper()

def main():
    # Usage:
    #   fasta_to_reads_fastq.py out.fastq read_len reads_per_ref seed ref1.fa ref2.fa ...
    if len(sys.argv) < 7:
        print("Usage: fasta_to_reads_fastq.py out.fastq read_len reads_per_ref seed ref1.fa ref2.fa [...]", file=sys.stderr)
        sys.exit(1)

    out_fastq = Path(sys.argv[1])
    read_len = int(sys.argv[2])
    reads_per_ref = int(sys.argv[3])
    seed = int(sys.argv[4])
    ref_files = [Path(x) for x in sys.argv[5:]]

    random.seed(seed)

    # Ensure output directory exists
    out_fastq.parent.mkdir(parents=True, exist_ok=True)

    with out_fastq.open("w") as out:
        for ref_path in ref_files:
            for header, seq in read_fasta(ref_path):
                if len(seq) < read_len:
                    continue

                # Write a fixed number of random reads per reference
                for i in range(reads_per_ref):
                    start = random.randint(0, len(seq) - read_len)
                    read = seq[start:start + read_len]
                    qual = "I" * read_len  # constant high quality
                    out.write(f"@{ref_path.stem}|{header}|read{i}|start{start}\n{read}\n+\n{qual}\n")

if __name__ == "__main__":
    main()
