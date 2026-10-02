"""Run the whole solution file and save every query result to lab3/results/.

  results/full_run.txt   complete psql log (queries, NOTICE messages, results)
  results/txt/*.txt      one psql table per query
  results/csv/*.csv      the same results as CSV (UTF-8 with BOM so Excel shows Cyrillic)
  results/README.md      which file belongs to which task and query

Each pass runs the file in a single psql session so temp tables stay available.
Usage: python scripts/save_results.py
"""
import re
import shutil
import subprocess

from build_report import DB_ENV, LAB_DIR, PSQL, solution_text, split_statements, split_tasks

OUT = LAB_DIR / "results"
RESULT_STATEMENT = re.compile(r"^(SELECT|EXPLAIN|WITH)\b", re.I)


def run(script, *args):
    result = subprocess.run(
        [str(PSQL), "-X", "-v", "ON_ERROR_STOP=1", *args],
        input=script.encode("utf-8"),
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        env=DB_ENV,
        check=True,
    )
    return result.stdout.decode("utf-8").replace("\r\n", "\n")


def queries():
    """Yield (name, task, comment, sql) for every statement in file order."""
    for task, code in sorted(split_tasks(solution_text()).items()):
        number = 0
        for sql in split_statements(code):
            # The comment block directly above the statement describes it.
            before = code[: code.index(sql)].rstrip().split("\n")
            block = []
            while before and before[-1].startswith("--"):
                block.insert(0, before.pop()[3:].strip())
            comment = " ".join(block)
            if RESULT_STATEMENT.match(sql):
                number += 1
                yield f"task{task:02d}_{number}", task, comment, sql
            else:
                yield None, task, comment, sql


def capture(fmt_args, folder, extension):
    """Run all statements, sending each result statement to its own file."""
    (OUT / folder).mkdir(parents=True, exist_ok=True)
    lines = []
    for name, _, _, sql in queries():
        if name:
            path = (OUT / folder / f"{name}.{extension}").as_posix()
            lines += [f"\\o '{path}'", sql, "\\o"]
        else:
            lines.append(sql)
    run("\n".join(lines) + "\n", "-q", *fmt_args)


def main():
    shutil.rmtree(OUT, ignore_errors=True)
    OUT.mkdir()

    (OUT / "full_run.txt").write_text(run(solution_text(), "-e"), encoding="utf-8")
    capture([], "txt", "txt")
    capture(["--csv"], "csv", "csv")

    for csv in (OUT / "csv").glob("*.csv"):
        csv.write_text(csv.read_text(encoding="utf-8"), encoding="utf-8-sig")

    rows = ["| Файл | Даалгавар | Тайлбар |", "|---|---|---|"]
    for name, task, comment, _ in queries():
        if name:
            rows.append(f"| `{name}` (.txt / .csv) | {task} | {comment} |")
    (OUT / "README.md").write_text(
        "# Lab 3 query results\n\n"
        "`full_run.txt` нь бүх файлыг ажиллуулсан бүрэн лог (NOTICE мессеж, DO блокийн алдааны жишээ орсон).\n"
        "`txt/` нь psql хүснэгт, `csv/` нь Excel-д нээх CSV.\n\n" + "\n".join(rows) + "\n",
        encoding="utf-8",
    )
    print(f"saved {len(list((OUT / 'txt').glob('*.txt')))} results to {OUT}")


if __name__ == "__main__":
    main()
