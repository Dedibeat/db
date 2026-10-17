"""Split the lab 4 solution files into sections and demo units.

A section starts with a header block:

    -- ============================================================
    -- Task 1. spTotalSales - ...
    -- ============================================================

Inside a section, the code before the first "-- Example" line is the procedure definition.
Every "-- Example X.Y: description" line starts a demo unit, which runs until the next
"-- Example" line or the end of the section. Each demo unit gets one screenshot slot.
"""
import os
import re
from dataclasses import dataclass, field
from pathlib import Path

LAB_DIR = Path(__file__).resolve().parent.parent
PSQL = Path(os.environ["LOCALAPPDATA"]) / "Programs/PostgreSQL/16/bin/psql.exe"

# Solution file -> database it runs on
FILES = {
    "pubs": LAB_DIR / "pubs_procedures.sql",
    "northwind": LAB_DIR / "northwind_procedures.sql",
}

DB_ENV = dict(
    os.environ,
    PGHOST="localhost",
    PGPORT="5432",
    PGUSER="dedibeat",
    PGCLIENTENCODING="UTF8",
)

HEADER = re.compile(r"^-- =+\n-- (?P<title>.+)\n-- =+\n", re.M)
DEMO = re.compile(r"^-- Example (?P<number>\d+\.\d+): (?P<text>.*)$", re.M)


@dataclass
class Demo:
    db: str
    number: str        # "1.2"
    description: str   # comment lines of the demo joined into one sentence
    code: str          # SQL including the leading comment lines

    @property
    def id(self):
        return f"{self.db}_{self.number.replace('.', '_')}"


@dataclass
class Section:
    db: str
    title: str         # "Task 1. spTotalSales - ..."
    definition: str    # code before the first demo (CREATE PROCEDURE ...)
    demos: list = field(default_factory=list)

    @property
    def number(self):
        m = re.match(r"Task (\d+)", self.title)
        return int(m.group(1)) if m else 0


def read(db):
    return FILES[db].read_text(encoding="utf-8").replace("\r\n", "\n")


def sections(db):
    """Return the sections of one solution file in file order."""
    text = read(db)
    heads = list(HEADER.finditer(text))
    result = []
    for i, head in enumerate(heads):
        end = heads[i + 1].start() if i + 1 < len(heads) else len(text)
        body = text[head.end():end].strip("\n") + "\n"
        demo_heads = list(DEMO.finditer(body))
        first = demo_heads[0].start() if demo_heads else len(body)
        section = Section(db, head.group("title").strip(), body[:first].strip("\n") + "\n")
        for j, m in enumerate(demo_heads):
            stop = demo_heads[j + 1].start() if j + 1 < len(demo_heads) else len(body)
            code = body[m.start():stop].strip("\n") + "\n"
            # Description: the "Example" line plus the comment lines right after it
            lines = [m.group("text").strip()]
            for line in code.split("\n")[1:]:
                if not line.startswith("--"):
                    break
                lines.append(line[2:].strip())
            section.demos.append(Demo(db, m.group("number"), " ".join(lines), code))
        result.append(section)
    return result


def file_header(db):
    """Comment block at the top of the file, before the first section."""
    text = read(db)
    return text[: HEADER.search(text).start()].strip("\n") + "\n"
