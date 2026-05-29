from html import escape


class PDFGenerator:
    @staticmethod
    def generate_bitacora_html(data: dict, fields: dict) -> str:
        module = escape(data.get("module", "desconocido"))
        date = escape(data.get("date", ""))
        html = f"""
        <html>
        <head><meta charset="utf-8"><style>
            body {{ font-family: Arial, sans-serif; padding: 20px; }}
            h1 {{ color: #1a237e; font-size: 18px; }}
            table {{ width: 100%; border-collapse: collapse; }}
            th, td {{ border: 1px solid #ccc; padding: 8px; text-align: left; }}
        </style></head>
        <body>
        <h1>BioLab LABSYNC - {module.upper()}</h1>
        <p><strong>Fecha:</strong> {date}</p>
        <table>
        """
        for key, value in fields.items():
            html += f"<tr><td>{escape(str(key))}</td><td>{escape(str(value))}</td></tr>"
        html += "</table></body></html>"
        return html

    @staticmethod
    def generate_cover_page_html(year: int, month: int, entries: list, closure_data: dict = None, generated_by: str = "Administrador") -> str:
        month_names = ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"]
        safe_generated_by = escape(generated_by)
        html = f"""
        <html>
        <head><meta charset="utf-8"><style>
            body {{ font-family: 'Times New Roman', serif; padding: 40px; text-align: center; }}
            h1 {{ font-size: 28px; color: #1a237e; }}
            .subtitle {{ font-size: 16px; color: #555; }}
            .meta {{ margin-top: 40px; font-size: 14px; }}
        </style></head>
        <body>
        <h1>BioLab LABSYNC Enterprise</h1>
        <h2>Reporte Mensual - {month_names[month-1]} {year}</h2>
        <p class="subtitle">{len(entries)} registros en el mes</p>
        <div class="meta">
            <p>Generado por: {safe_generated_by}</p>
        </div>
        </body></html>
        """
        return html

    @staticmethod
    def generate_closure_html(data: dict) -> str:
        return f"""
        <html>
        <head><meta charset="utf-8"><style>
            body {{ font-family: Arial, sans-serif; padding: 20px; }}
        </style></head>
        <body>
        <h2>Cierre del Dia - {escape(data.get('date', ''))}</h2>
        <p>Estado: {escape(data.get('status', ''))}</p>
        <p>Cerrado por: {escape(data.get('closed_by', ''))}</p>
        <p>Notas: {escape(data.get('notes', ''))}</p>
        </body></html>
        """
