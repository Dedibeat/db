#!/usr/bin/env python3
import json
import os
import subprocess

DB_NAME = "northwind"
DB_USER = os.environ.get("USER", "dedibeat")
DB_HOST = "/var/run/postgresql"
DB_PORT = "5432"

OUT_DIR = "output/ss"
os.makedirs(OUT_DIR, exist_ok=True)
os.makedirs("tmp", exist_ok=True)

HTML_TEMPLATE = """<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  * {{ box-sizing: border-box; margin: 0; padding: 0; }}
  html, body {{
    background: transparent;
    padding: 0;
    margin: 0;
    display: inline-block;
  }}
  .panel {{
    background: #181818;
    border: 1px solid #333333;
    border-radius: 6px;
    overflow: hidden;
    box-shadow: 0 4px 16px rgba(0,0,0,0.6);
    margin: 8px;
    display: inline-block;
  }}
  .panel-header {{
    background: #252526;
    padding: 8px 16px;
    border-bottom: 1px solid #333333;
    font-size: 12px;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "DejaVu Sans", sans-serif;
    color: #9cdcfe;
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 24px;
  }}
  .panel-header .title {{
    font-weight: 600;
    letter-spacing: 0.2px;
  }}
  .panel-header .meta {{
    color: #858585;
    font-size: 11px;
    background: #1e1e1e;
    padding: 2px 8px;
    border-radius: 10px;
    border: 1px solid #3c3c3c;
  }}
  table {{
    border-collapse: collapse;
    font-family: 'DejaVu Sans Mono', Consolas, monospace;
    font-size: 11.5px;
    line-height: 1.45;
  }}
  th {{
    background: #1f1f1f;
    color: #4ec9b0;
    font-weight: 600;
    padding: 6px 14px;
    border-bottom: 2px solid #383838;
    border-right: 1px solid #2d2d2d;
    white-space: nowrap;
    text-align: left;
  }}
  th.num {{ text-align: right; }}
  th.center {{ text-align: center; }}
  th:last-child {{ border-right: none; }}
  td {{
    padding: 5px 14px;
    border-bottom: 1px solid #262626;
    border-right: 1px solid #262626;
    color: #cccccc;
    white-space: nowrap;
  }}
  td:last-child {{ border-right: none; }}
  tr:nth-child(even) td {{
    background: #151515;
  }}
  tr:nth-child(odd) td {{
    background: #1c1c1c;
  }}
  td.num {{ text-align: right; color: #b5cea8; }}
  td.text {{ text-align: left; }}
  td.date {{ text-align: center; color: #ce9178; }}
  td.id {{ text-align: right; color: #9cdcfe; font-weight: 600; }}
  td.rank {{ text-align: center; color: #dcdcaa; font-weight: bold; }}
  
  .badge {{
    display: inline-block;
    padding: 1px 7px;
    border-radius: 3px;
    font-size: 11px;
    font-weight: 600;
    text-align: center;
  }}
  .badge-ok {{ background: rgba(78, 201, 176, 0.18); color: #4ec9b0; border: 1px solid rgba(78, 201, 176, 0.4); }}
  .badge-low {{ background: rgba(220, 220, 170, 0.18); color: #dcdcaa; border: 1px solid rgba(220, 220, 170, 0.4); }}
  .badge-reorder {{ background: rgba(244, 71, 71, 0.22); color: #f48771; border: 1px solid rgba(244, 71, 71, 0.5); }}
  .badge-late {{ background: rgba(244, 71, 71, 0.22); color: #f48771; border: 1px solid rgba(244, 71, 71, 0.5); }}
  .badge-ontime {{ background: rgba(78, 201, 176, 0.18); color: #4ec9b0; border: 1px solid rgba(78, 201, 176, 0.4); }}

  /* Console error styling */
  .console {{
    background: #181818;
    color: #cccccc;
    font-family: 'DejaVu Sans Mono', Consolas, monospace;
    font-size: 12px;
    padding: 14px 18px;
    border-left: 4px solid #f44747;
    line-height: 1.55;
    min-width: 680px;
  }}
  .console .cmd {{
    color: #9cdcfe;
    margin-bottom: 8px;
  }}
  .console .err {{
    color: #f48771;
    font-weight: 600;
  }}
  .console .detail {{
    color: #858585;
    margin-top: 4px;
  }}
</style>
</head>
<body>
{content}
</body>
</html>
"""

def run_query(sql):
    cmd = [
        "psql", "-X", "-h", DB_HOST, "-p", DB_PORT, "-U", DB_USER, "-d", DB_NAME,
        "-t", "-A", "-c", f"SELECT json_agg(t) FROM ({sql}) t;"
    ]
    res = subprocess.check_output(cmd).decode("utf-8").strip()
    if not res or res == "NULL":
        return []
    return json.loads(res)

def render_html_to_png(html_content, out_png, width=2000, height=2000):
    tmp_html = f"tmp/{os.path.basename(out_png)}.html"
    tmp_raw_png = f"tmp/{os.path.basename(out_png)}.raw.png"
    with open(tmp_html, "w", encoding="utf-8") as f:
        f.write(html_content)
    
    subprocess.run([
        "google-chrome",
        "--headless=new",
        "--disable-gpu",
        "--force-device-scale-factor=2",
        f"--screenshot={tmp_raw_png}",
        f"--window-size={width},{height}",
        "--default-background-color=00000000",
        tmp_html
    ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    subprocess.run([
        "convert",
        tmp_raw_png,
        "-trim",
        "+repage",
        out_png
    ], check=True)
    print(f"Rendered {out_png}")

def build_table(headers, rows, title, meta=None, col_types=None):
    if col_types is None:
        col_types = ["text"] * len(headers)
    
    th_html = ""
    for h, ct in zip(headers, col_types):
        c_class = "num" if ct in ["num", "id", "rank"] else ("center" if ct in ["date", "badge"] else "text")
        th_html += f"<th class='{c_class}'>{h}</th>"
    
    tr_html = ""
    for r in rows:
        td_html = ""
        for val, ct in zip(r, col_types):
            c_class = ct
            val_str = str(val) if val is not None else "NULL"
            
            if ct == "num" and isinstance(val, (int, float)):
                val_str = f"{val:,.2f}" if isinstance(val, float) else f"{val:,}"
            elif ct == "badge":
                if val in ["OK", "On time"]:
                    val_str = f"<span class='badge badge-ok'>{val}</span>"
                elif val in ["Low"]:
                    val_str = f"<span class='badge badge-low'>{val}</span>"
                elif val in ["Reorder needed", "Late"]:
                    val_str = f"<span class='badge badge-reorder'>{val}</span>"
                else:
                    val_str = f"<span class='badge'>{val}</span>"
            elif ct == "rank":
                val_str = f"{val}"
            
            td_html += f"<td class='{c_class}'>{val_str}</td>"
        tr_html += f"<tr>{td_html}</tr>\n"
    
    meta_str = f"<span class='meta'>{meta}</span>" if meta else ""
    return f"""
    <div class='panel'>
      <div class='panel-header'>
        <span class='title'>{title}</span>
        {meta_str}
      </div>
      <table>
        <thead><tr>{th_html}</tr></thead>
        <tbody>{tr_html}</tbody>
      </table>
    </div>
    """

def main():
    # Ex 1: Top 10 orders
    data = run_query("""
        SELECT order_id, customer_id, order_date::text, ROUND(order_total, 2)::float AS order_total
        FROM v_order_totals
        ORDER BY order_total DESC, order_id
        LIMIT 10
    """)
    rows = [[d["order_id"], d["customer_id"], d["order_date"], d["order_total"]] for d in data]
    table = build_table(
        ["order_id", "customer_id", "order_date", "order_total"],
        rows,
        "v_order_totals — Нийт дүнгээр тэргүүлэгч 10 захиалга",
        meta="10 rows",
        col_types=["id", "text", "date", "num"]
    )
    render_html_to_png(HTML_TEMPLATE.format(content=table), f"{OUT_DIR}/ex1_order_totals.png")

    # Ex 2: High AOV customers (all columns including average_order_value!)
    data = run_query("""
        SELECT customer_id, company_name, country, order_count,
               ROUND(total_revenue, 2)::float AS total_revenue,
               ROUND(average_order_value, 2)::float AS average_order_value,
               last_order_date::text
        FROM v_customer_sales
        WHERE average_order_value > (SELECT AVG(order_total) FROM v_order_totals)
        ORDER BY average_order_value DESC, customer_id
    """)
    rows = [[d["customer_id"], d["company_name"], d["country"], d["order_count"], d["total_revenue"], d["average_order_value"], d["last_order_date"]] for d in data]
    table = build_table(
        ["customer_id", "company_name", "country", "order_count", "total_revenue", "average_order_value", "last_order_date"],
        rows,
        "v_customer_sales — Захиалгын дундаж дүн өндөртэй харилцагчид",
        meta=f"{len(rows)} rows",
        col_types=["id", "text", "text", "num", "num", "num", "date"]
    )
    render_html_to_png(HTML_TEMPLATE.format(content=table), f"{OUT_DIR}/ex2_customer_sales.png")

    # Ex 3: Category rank top 3
    data = run_query("""
        SELECT category_name, product_name,
               ROUND(total_sales, 2)::float AS total_sales,
               sales_rank
        FROM v_product_category_rank
        WHERE sales_rank <= 3
        ORDER BY category_name, sales_rank, product_name
    """)
    rows = [[d["category_name"], d["product_name"], d["total_sales"], d["sales_rank"]] for d in data]
    table = build_table(
        ["category_name", "product_name", "total_sales", "sales_rank"],
        rows,
        "v_product_category_rank — Ангилал бүрийн шилдэг 3 бүтээгдэхүүн",
        meta="24 rows (8 categories)",
        col_types=["text", "text", "num", "rank"]
    )
    render_html_to_png(HTML_TEMPLATE.format(content=table), f"{OUT_DIR}/ex3_category_rank.png")

    # Ex 4: Employee hierarchy
    data = run_query("""
        SELECT employee_id, employee_name, manager_id, manager_name, depth, path
        FROM v_employee_hierarchy
        ORDER BY depth, employee_id
    """)
    rows = [[d["employee_id"], d["employee_name"], d["manager_id"], d["manager_name"], d["depth"], d["path"]] for d in data]
    table = build_table(
        ["employee_id", "employee_name", "manager_id", "manager_name", "depth", "path"],
        rows,
        "v_employee_hierarchy — Рекурсив CTE ажилтны шатлал",
        meta="9 rows",
        col_types=["id", "text", "num", "text", "num", "text"]
    )
    render_html_to_png(HTML_TEMPLATE.format(content=table), f"{OUT_DIR}/ex4_employee_hierarchy.png")

    # Ex 5: Success test
    rows = [[32000, "Lab Test Product", 12.00, 0]]
    table = build_table(
        ["product_id", "product_name", "unit_price", "discontinued"],
        rows,
        "v_active_products — Амжилттай INSERT ба UPDATE шалгалт (Transaction)",
        meta="1 row",
        col_types=["id", "text", "num", "num"]
    )
    render_html_to_png(HTML_TEMPLATE.format(content=table), f"{OUT_DIR}/ex5_success.png")

    # Ex 5: CHECK OPTION violation error console
    err_html = """
    <div class='panel'>
      <div class='panel-header'>
        <span class='title'>PostgreSQL Асуулга — WITH CHECK OPTION Шалгалтын Алдаа</span>
        <span class='meta'>ERROR (44000)</span>
      </div>
      <div class='console'>
        <div class='cmd'>psql&gt; UPDATE v_active_products SET discontinued = 1 WHERE product_id = 3;</div>
        <div class='err'>ERROR: new row violates check option for view "v_active_products"</div>
        <div class='detail'>DETAIL: Failing row contains (3, Aniseed Syrup, 1, 2, 12 - 550 ml bottles, 10, 13, 70, 25, 1).</div>
      </div>
    </div>
    """
    render_html_to_png(HTML_TEMPLATE.format(content=err_html), f"{OUT_DIR}/ex5_violation_error.png")

    # Ex 6: Materialized view monthly sales (excerpt)
    data = run_query("""
        SELECT year_month::text, country, order_count,
               ROUND(total_revenue, 2)::float AS total_revenue
        FROM mv_monthly_sales
        ORDER BY year_month, country
        LIMIT 14
    """)
    rows = [[d["year_month"], d["country"], d["order_count"], d["total_revenue"]] for d in data]
    table = build_table(
        ["year_month", "country", "order_count", "total_revenue"],
        rows,
        "mv_monthly_sales — Материалчлагдсан харагдац (Эхний 14 мөрийн хэсэг)",
        meta="Excerpt: 14 of 322 rows",
        col_types=["date", "text", "num", "num"]
    )
    render_html_to_png(HTML_TEMPLATE.format(content=table), f"{OUT_DIR}/ex6_monthly_sales.png")

    # Ex 7: Category Pivot table (excerpt)
    data = run_query("""
        SELECT
            customer_id,
            company_name,
            ROUND(beverages, 2)::float AS beverages,
            ROUND(condiments, 2)::float AS condiments,
            ROUND(confections, 2)::float AS confections,
            ROUND(dairy_products, 2)::float AS dairy_products,
            ROUND(grains_cereals, 2)::float AS grains_cereals,
            ROUND(meat_poultry, 2)::float AS meat_poultry,
            ROUND(produce, 2)::float AS produce,
            ROUND(seafood, 2)::float AS seafood,
            ROUND(total_revenue, 2)::float AS total_revenue
        FROM v_customer_category_pivot
        ORDER BY customer_id
        LIMIT 12
    """)
    rows = [[
        d["customer_id"], d["company_name"], d["beverages"], d["condiments"],
        d["confections"], d["dairy_products"], d["grains_cereals"], d["meat_poultry"],
        d["produce"], d["seafood"], d["total_revenue"]
    ] for d in data]
    table = build_table(
        ["customer_id", "company_name", "beverages", "condiments", "confections", "dairy", "grains", "meat", "produce", "seafood", "total_revenue"],
        rows,
        "v_customer_category_pivot — 8 ангиллаар пивот хийсэн борлуулалт (Хэсэг)",
        meta="Excerpt: 12 of 91 rows",
        col_types=["id", "text", "num", "num", "num", "num", "num", "num", "num", "num", "num"]
    )
    render_html_to_png(HTML_TEMPLATE.format(content=table), f"{OUT_DIR}/ex7_category_pivot.png")

    # Ex 7: Dominant category (> 50%)
    data = run_query("""
        SELECT
            p.company_name,
            d.category_name AS dominant_category,
            ROUND(d.category_revenue, 2)::float AS dominant_revenue,
            ROUND(p.total_revenue, 2)::float AS total_revenue,
            ROUND(100 * d.category_revenue / p.total_revenue, 1)::float AS share
        FROM v_customer_category_pivot AS p
        CROSS JOIN LATERAL (
            VALUES
                ('Beverages', p.beverages),
                ('Condiments', p.condiments),
                ('Confections', p.confections),
                ('Dairy Products', p.dairy_products),
                ('Grains/Cereals', p.grains_cereals),
                ('Meat/Poultry', p.meat_poultry),
                ('Produce', p.produce),
                ('Seafood', p.seafood)
        ) AS d(category_name, category_revenue)
        WHERE p.total_revenue > 0
          AND d.category_revenue > p.total_revenue * 0.50
        ORDER BY share DESC, p.company_name
    """)
    rows = [[d["company_name"], d["dominant_category"], d["dominant_revenue"], d["total_revenue"], d["share"]] for d in data]
    table = build_table(
        ["company_name", "dominant_category", "dominant_revenue", "total_revenue", "share (%)"],
        rows,
        "v_customer_category_pivot — Нэг ангилал нь 50%-иас их орлого эзэлдэг харилцагчид",
        meta="18 rows",
        col_types=["text", "text", "num", "num", "num"]
    )
    render_html_to_png(HTML_TEMPLATE.format(content=table), f"{OUT_DIR}/ex7_dominant_category.png")

    # Ex 8: Monthly decrease
    data = run_query("""
        SELECT
            category_name,
            month::text,
            ROUND(previous_revenue, 2)::float AS previous_revenue,
            ROUND(current_revenue, 2)::float AS current_revenue,
            ROUND(change_amount, 2)::float AS change_amount,
            ROUND(change_percent, 2)::float AS change_percent
        FROM v_category_monthly_change
        WHERE previous_revenue IS NOT NULL
        ORDER BY change_amount ASC
        LIMIT 1
    """)
    rows = [[d["category_name"], d["month"], d["previous_revenue"], d["current_revenue"], d["change_amount"], d["change_percent"]] for d in data]
    table = build_table(
        ["category_name", "month", "previous_revenue", "current_revenue", "change_amount", "change_percent (%)"],
        rows,
        "v_category_monthly_change — Хамгийн их сарын бууралттай ангилал",
        meta="1 row (Top decrease)",
        col_types=["text", "date", "num", "num", "num", "num"]
    )
    render_html_to_png(HTML_TEMPLATE.format(content=table), f"{OUT_DIR}/ex8_monthly_decrease.png")

    # Ex 9: Late shipment performance
    data = run_query("""
        SELECT
            shipper_name,
            COUNT(*) FILTER (WHERE shipped_date IS NOT NULL) AS shipped_orders,
            COUNT(*) FILTER (WHERE shipment_status = 'Late') AS late_orders,
            ROUND(
                100.0 * COUNT(*) FILTER (WHERE shipment_status = 'Late')
                / NULLIF(COUNT(*) FILTER (WHERE shipped_date IS NOT NULL), 0),
                2
            )::float AS late_percentage,
            ROUND(
                AVG(delivery_days) FILTER (WHERE shipment_status = 'Late'),
                2
            )::float AS average_late_days
        FROM v_shipment_performance
        GROUP BY shipper_name
        ORDER BY late_percentage DESC, average_late_days DESC
    """)
    rows = [[d["shipper_name"], d["shipped_orders"], d["late_orders"], d["late_percentage"], d["average_late_days"]] for d in data]
    table = build_table(
        ["shipper_name", "shipped_orders", "late_orders", "late_percentage (%)", "average_late_days"],
        rows,
        "v_shipment_performance — Тээвэрлэгчдийн хоцролтын шинжилгээ",
        meta="3 rows",
        col_types=["text", "num", "num", "num", "num"]
    )
    render_html_to_png(HTML_TEMPLATE.format(content=table), f"{OUT_DIR}/ex9_shipment_performance.png")

    # Ex 10: Inventory status excerpt
    data = run_query("""
        SELECT
            product_name,
            supplier_name,
            category_name,
            unit_price::float AS unit_price,
            units_in_stock,
            units_on_order,
            reorder_level,
            ROUND(stock_value, 2)::float AS stock_value,
            stock_status
        FROM v_product_inventory_status
        ORDER BY
            CASE stock_status
                WHEN 'Reorder needed' THEN 1
                WHEN 'Low' THEN 2
                ELSE 3
            END,
            supplier_name, product_name
        LIMIT 16
    """)
    rows = [[
        d["product_name"], d["supplier_name"], d["category_name"], d["unit_price"],
        d["units_in_stock"], d["units_on_order"], d["reorder_level"], d["stock_value"],
        d["stock_status"]
    ] for d in data]
    table = build_table(
        ["product_name", "supplier_name", "category_name", "unit_price", "units_in_stock", "units_on_order", "reorder_level", "stock_value", "stock_status"],
        rows,
        "v_product_inventory_status — Бараа материалын төлөвийн түүвэр (Төлөөлөл)",
        meta="Excerpt: 16 representative rows (Reorder needed, Low, OK)",
        col_types=["text", "text", "text", "num", "num", "num", "num", "num", "badge"]
    )
    render_html_to_png(HTML_TEMPLATE.format(content=table), f"{OUT_DIR}/ex10_inventory_status.png")

    # Ex 10: Supplier reorder summary
    data = run_query("""
        SELECT
            supplier_name,
            COUNT(*) FILTER (WHERE stock_status = 'Reorder needed') AS reorder_products,
            ROUND(
                SUM(stock_value) FILTER (WHERE stock_status = 'Reorder needed'),
                2
            )::float AS total_stock_value
        FROM v_product_inventory_status
        GROUP BY supplier_id, supplier_name
        HAVING COUNT(*) FILTER (WHERE stock_status = 'Reorder needed') > 0
        ORDER BY reorder_products DESC, supplier_name
    """)
    rows = [[d["supplier_name"], d["reorder_products"], d["total_stock_value"]] for d in data]
    table = build_table(
        ["supplier_name", "reorder_products", "total_stock_value"],
        rows,
        "v_product_inventory_status — Дахин захиалах шаардлагатай нийлүүлэгчдийн хураангуй",
        meta="2 rows",
        col_types=["text", "num", "num"]
    )
    render_html_to_png(HTML_TEMPLATE.format(content=table), f"{OUT_DIR}/ex10_supplier_reorder.png")

    print("All screenshots generated successfully!")

if __name__ == "__main__":
    main()
