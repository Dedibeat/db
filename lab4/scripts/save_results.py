"""Run both solution files and save the real psql output of every demo to results/.

  results/full_run_pubs.txt, full_run_northwind.txt   complete psql log of each file
  results/txt/<demo id>.txt                            output of one demo (statements,
                                                       NOTICE messages and result tables)
  results/README.md                                    which file belongs to which demo

Each file runs in one psql session with ON_ERROR_STOP, so the procedures are created
first and every demo runs right after them, exactly as in the .sql file.
Usage: python scripts/save_results.py
"""
import re
import shutil
import subprocess

from sqlfile import DB_ENV, FILES, LAB_DIR, PSQL, read, sections

OUT = LAB_DIR / "results"
MARK = "@@@DEMO "


def run(db, script):
    result = subprocess.run(
        [str(PSQL), "-X", "-d", db, "-v", "ON_ERROR_STOP=1", "-e"],
        input=script.encode("utf-8"),
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        env=DB_ENV,
        check=True,
    )
    text = result.stdout.decode("utf-8").replace("\r\n", "\n")
    # "psql:<stdin>:12: NOTICE: ..." -> "NOTICE: ..."
    return re.sub(r"^psql:<stdin>:\d+: ", "", text, flags=re.M)


def main():
    shutil.rmtree(OUT, ignore_errors=True)
    (OUT / "txt").mkdir(parents=True)
    rows = ["| Файл | Өгөгдлийн сан | Хэсэг | Жишээ |", "|---|---|---|---|"]

    for db in FILES:
        (OUT / f"full_run_{db}.txt").write_text(run(db, read(db)), encoding="utf-8")

        # Same file again, with a marker line before every demo and after its section.
        parts = []
        for section in sections(db):
            parts.append(section.definition)
            for demo in section.demos:
                parts += [f"\\echo '{MARK}{demo.id}'", demo.code]
            parts.append(f"\\echo '{MARK}end'")
        output = run(db, "\n".join(parts))

        for chunk in output.split(MARK)[1:]:
            name, _, body = chunk.partition("\n")
            if name == "end":
                continue
            (OUT / "txt" / f"{name}.txt").write_text(body.strip("\n") + "\n", encoding="utf-8")

        for section in sections(db):
            for demo in section.demos:
                rows.append(f"| `txt/{demo.id}.txt` | {db} | {section.title} | {demo.number}: {demo.description} |")

    (OUT / "README.md").write_text(
        "# Lab 4 query results\n\n"
        "Энэ хавтасны бүх файл нь `python scripts/save_results.py`-ээр psql-ийг бодитоор ажиллуулж хадгалсан гаралт.\n"
        "`full_run_*.txt` нь .sql файлыг бүтнээр нь ажиллуулсан лог, `txt/` нь жишээ тус бүрийн гаралт "
        "(SQL, NOTICE мессеж, үр дүнгийн хүснэгт).\n\n" + "\n".join(rows) + "\n",
        encoding="utf-8",
    )
    print(f"saved {len(list((OUT / 'txt').glob('*.txt')))} demo outputs to {OUT}")


if __name__ == "__main__":
    main()
