#!/usr/bin/env python3
"""
PDF Report Generator for SysAudit
Converts HTML audit reports to professional PDF documents
"""

import sys
import os
import logging

def generate_pdf(html_file_path, output_pdf_path):
    """
    Generates a PDF from an HTML file using WeasyPrint.
    Includes comprehensive error handling and dependency checking.
    """
    # Validate input file exists
    if not os.path.exists(html_file_path):
        print(f"Error: HTML file not found at {html_file_path}", file=sys.stderr)
        sys.exit(1)

    # Check file size
    file_size = os.path.getsize(html_file_path)
    if file_size == 0:
        print(f"Error: HTML file is empty: {html_file_path}", file=sys.stderr)
        sys.exit(1)

    try:
        # Import WeasyPrint (delay import to provide better error message)
        from weasyprint import HTML, CSS
        import warnings
        warnings.filterwarnings('ignore')  # Suppress WeasyPrint warnings
        
        # Configure logging to suppress verbose output
        logging.getLogger('weasyprint').setLevel(logging.ERROR)
        logging.getLogger('fontTools').setLevel(logging.ERROR)
        
        # Load HTML from the file
        html = HTML(filename=html_file_path)
        
        # Generate PDF with optimizations
        html.write_pdf(
            output_pdf_path,
            presentational_hints=True,
            optimize_images=True
        )
        
        # Verify PDF was created
        if os.path.exists(output_pdf_path) and os.path.getsize(output_pdf_path) > 0:
            print(f"✓ PDF generated: {output_pdf_path} ({os.path.getsize(output_pdf_path)} bytes)")
            sys.exit(0)
        else:
            print(f"Error: PDF file was not created properly", file=sys.stderr)
            sys.exit(1)
            
    except ImportError as e:
        print(f"Error: WeasyPrint module not found. Install with:", file=sys.stderr)
        print(f"  pip3 install --user weasyprint", file=sys.stderr)
        print(f"  Or: sudo apt install python3-weasyprint", file=sys.stderr)
        print(f"\nDetails: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error generating PDF from {html_file_path}:", file=sys.stderr)
        print(f"  {type(e).__name__}: {e}", file=sys.stderr)
        # Additional diagnostics
        if "cairo" in str(e).lower() or "pango" in str(e).lower():
            print(f"\nSystem dependency issue. Install with:", file=sys.stderr)
            print(f"  sudo apt install libcairo2 libpango-1.0-0 libpangocairo-1.0-0", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: generate_pdf.py <input_html_file> <output_pdf_file>", file=sys.stderr)
        print("\nExample:", file=sys.stderr)
        print("  python3 generate_pdf.py report.html report.pdf", file=sys.stderr)
        sys.exit(1)

    input_html = sys.argv[1]
    output_pdf = sys.argv[2]
    generate_pdf(input_html, output_pdf)
