"""Build the Lab 3 report.

Steps:
  1. Split the solution .sql file into one highlighted LaTeX listing per task
     (report/sql/taskN.tex). Pygments is used because the listings package
     reorders Cyrillic characters under XeLaTeX.
  2. Render the full CTE plan from psql into report/img/ (the only figure that is not
     a VS Code screenshot).
  3. Compile report/report.tex with xelatex and copy the PDF next to the .sql file.

Usage: python scripts/build_report.py [--no-shots] [--no-pdf]
"""
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont
from pygments import highlight
from pygments.formatters import LatexFormatter
from pygments.lexers import PostgresLexer
from pygments.style import Style
from pygments.token import Comment, Keyword, Name, String

LAB_DIR = Path(__file__).resolve().parent.parent
REPORT_DIR = LAB_DIR / "report"
SQL_OUT = REPORT_DIR / "sql"
IMG_OUT = REPORT_DIR / "img"
SOLUTION = next(LAB_DIR.glob("23B1NUM1470_*.sql"))
PSQL = Path(os.environ["LOCALAPPDATA"]) / "Programs/PostgreSQL/16/bin/psql.exe"

DB_ENV = dict(
    os.environ,
    PGHOST="localhost",
    PGPORT="5432",
    PGUSER="dedibeat",
    PGDATABASE="northwind",
    PGCLIENTENCODING="UTF8",
)


# ---------------------------------------------------------------------------
# 1. SQL sections and statements
# ---------------------------------------------------------------------------

def solution_text():
    return SOLUTION.read_text(encoding="utf-8")


def split_tasks(text):
    """Return {task_number: code} using the '-- Даалгавар N' header lines."""
    parts = re.split(r"^-- =+\n(?=-- Даалгавар \d+)", text, flags=re.M)
    tasks = {}
    for part in parts[1:]:
        number = int(re.match(r"-- Даалгавар (\d+)", part).group(1))
        body = re.sub(r"^-- Даалгавар .*\n-- =+\n", "", part, flags=re.M)
        tasks[number] = body.strip() + "\n"
    return tasks


def split_statements(text):
    """Split SQL into statements, keeping dollar-quoted bodies together."""
    statements, current, in_dollar = [], [], False
    for line in text.splitlines():
        if not current and (not line.strip() or line.startswith("--")):
            continue
        current.append(line)
        if line.count("$$") % 2 == 1:
            in_dollar = not in_dollar
        if not in_dollar and line.rstrip().endswith(";"):
            statements.append("\n".join(current))
            current = []
    return statements


STATEMENTS = split_statements(solution_text())


def stmt(fragment):
    """Find the single statement in the solution file that contains `fragment`."""
    matches = [s for s in STATEMENTS if fragment in s]
    if len(matches) != 1:
        raise ValueError(f"{len(matches)} statements match {fragment!r}")
    return matches[0]


# ---------------------------------------------------------------------------
# 2. Screenshots
# ---------------------------------------------------------------------------

# All other figures are VS Code SQLTools screenshots (report/img/ss1-30.png).
# psql is rendered only for the full CTE plan, because SQLTools truncates long plan lines.
SHOTS = [
    # name, hidden setup statements, shown statement, max data rows
    ("ex10e", ["SELECT * FROM abc_analysis_cte(1997);"],
     stmt("EXPLAIN (ANALYZE, BUFFERS)\nSELECT * FROM abc_analysis_cte(1997)"), 100),
]


def run_psql(setup, shown):
    """Run hidden setup statements, then the shown statement; return the shown output."""
    marker = "@@@SHOT@@@"
    script = "\n".join(
        ["SET client_min_messages = warning;", *setup, "RESET client_min_messages;",
         f"\\echo {marker}", shown, ""]
    )
    result = subprocess.run(
        [str(PSQL), "-X", "-q"],
        input=script.encode("utf-8"),
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        env=DB_ENV,
        check=False,
    )
    text = result.stdout.decode("utf-8").replace("\r\n", "\n")
    output = text.split(marker + "\n", 1)[1]
    output = re.sub(r"^psql:<stdin>:\d+: ", "", output, flags=re.M)
    return output.rstrip("\n")


def truncate_rows(output, max_rows):
    """Keep the header, the first max_rows data rows and the '(N rows)' footer."""
    lines = output.split("\n")
    sep = next((i for i, l in enumerate(lines) if re.fullmatch(r"-+(\+-+)*", l)), None)
    footer = next((i for i, l in enumerate(lines) if re.fullmatch(r"\(\d+ rows?\)", l)), None)
    if sep is None or footer is None or footer - sep - 1 <= max_rows:
        return output
    return "\n".join(lines[: sep + 1 + max_rows] + ["..."] + lines[footer:])


def prompt_lines(sql, in_transaction):
    """Prefix the statement lines the way interactive psql shows them."""
    marker = "*" if in_transaction else ""
    lines, depth = [], 0
    for i, line in enumerate(sql.split("\n")):
        if i == 0:
            prompt = f"northwind={marker}> "
        else:
            prompt = f"northwind{'(' if depth > 0 else '-'}{marker}> "
        lines.append((prompt, line))
        code = line.split("--")[0]
        depth += code.count("(") - code.count(")")
    return lines


FONT = ImageFont.truetype(r"C:\Windows\Fonts\consola.ttf", 26)
TITLE_FONT = ImageFont.truetype(r"C:\Windows\Fonts\segoeui.ttf", 22)
BG = (12, 12, 12)
TITLE_BG = (32, 32, 32)
FG = (204, 204, 204)
PROMPT = (22, 198, 12)
SQL_FG = (242, 242, 242)
NOTICE = (249, 241, 165)
ERROR = (231, 72, 86)
DIM = (140, 140, 140)


def render(name, prompt, output):
    char_w = FONT.getlength("M")
    line_h = 34
    pad_x, pad_y, title_h = 26, 20, 46

    body = [(p, l, "sql") for p, l in prompt] + [("", l, "out") for l in output.split("\n")]
    max_chars = max(len(p) + len(l) for p, l, _ in body)
    width = int(max(max_chars * char_w + 2 * pad_x, 900))
    height = title_h + 2 * pad_y + line_h * len(body)

    img = Image.new("RGB", (width, height), BG)
    draw = ImageDraw.Draw(img)
    draw.rectangle([0, 0, width, title_h], fill=TITLE_BG)
    draw.text((pad_x, 10), "psql  ·  dedibeat@northwind  ·  PostgreSQL 16", font=TITLE_FONT, fill=DIM)

    y = title_h + pad_y
    for p, line, kind in body:
        x = pad_x
        if kind == "sql":
            draw.text((x, y), p, font=FONT, fill=PROMPT)
            draw.text((x + len(p) * char_w, y), line, font=FONT, fill=SQL_FG)
        else:
            color = FG
            if re.match(r"(ERROR|DETAIL|HINT):", line):
                color = ERROR
            elif line.startswith("CONTEXT:"):
                color = DIM
            elif line.startswith("NOTICE:"):
                color = NOTICE
            draw.text((x, y), line, font=FONT, fill=color)
        y += line_h

    img.save(IMG_OUT / f"{name}.png")


def make_shots():
    IMG_OUT.mkdir(parents=True, exist_ok=True)
    for name, setup, shown, max_rows in SHOTS:
        output = truncate_rows(run_psql(setup, shown), max_rows)
        render(name, prompt_lines(shown, "BEGIN;" in setup), output)
        print(f"screenshot {name}.png")


# ---------------------------------------------------------------------------
# 3. PDF
# ---------------------------------------------------------------------------

class ReportStyle(Style):
    styles = {
        Keyword: "bold #214F73",
        Name.Builtin: "#214F73",
        Comment: "#3D6B35",
        String: "#8B3A1A",
    }


LATEX = LatexFormatter(
    style=ReportStyle,
    verboptions=r"fontsize=\fontsize{8.3}{9.9}\selectfont, frame=leftline, framerule=1.2pt,"
                r" rulecolor=\color{sqlblue!35}, framesep=6pt, xleftmargin=8pt",
)


def write_sql_sections():
    SQL_OUT.mkdir(parents=True, exist_ok=True)
    (SQL_OUT / "pygments-style.tex").write_text(LATEX.get_style_defs(), encoding="utf-8")
    for number, code in split_tasks(solution_text()).items():
        tex = highlight(code, PostgresLexer(), LATEX)
        (SQL_OUT / f"task{number}.tex").write_text(tex, encoding="utf-8")


def build_pdf():
    for _ in range(2):
        subprocess.run(
            ["xelatex", "-interaction=nonstopmode", "-halt-on-error", "report.tex"],
            cwd=REPORT_DIR, check=True, stdout=subprocess.DEVNULL,
        )
    target = SOLUTION.with_suffix(".pdf")
    shutil.copyfile(REPORT_DIR / "report.pdf", target)
    print(f"report {target.name}")


if __name__ == "__main__":
    write_sql_sections()
    if "--no-shots" not in sys.argv:
        make_shots()
    if "--no-pdf" not in sys.argv:
        build_pdf()
