#!/usr/bin/env python3
"""
Automated Documentation Generator for Ansible Roles.
Parses meta/argument_specs.yml across all roles to generate comprehensive Markdown docs.
"""

import os
import yaml
from pathlib import Path

def generate_role_doc(role_name, specs):
    if not specs or 'main' not in specs:
        return ""
        
    main_specs = specs['main']
    short_desc = main_specs.get('short_description', 'No description provided.')
    desc = main_specs.get('description', '')
    if isinstance(desc, list):
        desc = " ".join(desc)
        
    doc = f"# Role: `{role_name}`\n\n"
    doc += f"**{short_desc}**\n\n"
    if desc:
        doc += f"{desc}\n\n"
        
    options = main_specs.get('options', {})
    if options:
        doc += "## Role Variables\n\n"
        doc += "| Variable | Type | Required | Default | Description |\n"
        doc += "|---|---|---|---|---|\n"
        for var_name, var_details in options.items():
            v_type = var_details.get('type', 'str')
            v_req = str(var_details.get('required', False))
            v_def = str(var_details.get('default', 'None'))
            v_desc = var_details.get('description', '')
            if isinstance(v_desc, list):
                v_desc = " ".join(v_desc)
            doc += f"| `{var_name}` | `{v_type}` | {v_req} | `{v_def}` | {v_desc} |\n"
    else:
        doc += "## Role Variables\n\n*This role accepts no customizable variables.*\n"
        
    return doc

def main():
    base_dir = Path(__file__).parent.parent
    roles_dir = base_dir / "roles"
    docs_dir = base_dir / "docs"
    docs_dir.mkdir(exist_ok=True)
    
    index_md = "# Component Documentation\n\nThis directory contains auto-generated documentation for all Ansible roles in this collection, parsed directly from their `meta/argument_specs.yml` declarations.\n\n## Available Roles\n\n"
    
    roles = sorted([d.name for d in roles_dir.iterdir() if d.is_dir()])
    
    for role in roles:
        specs_file = roles_dir / role / "meta" / "argument_specs.yml"
        if specs_file.exists():
            with open(specs_file, "r") as f:
                try:
                    data = yaml.safe_load(f)
                    specs = data.get('argument_specs', {})
                    role_doc = generate_role_doc(role, specs)
                    
                    if role_doc:
                        out_path = docs_dir / f"{role}.md"
                        with open(out_path, "w") as out:
                            out.write(role_doc)
                        
                        short_desc = specs.get('main', {}).get('short_description', '')
                        index_md += f"- [{role}]({role}.md): {short_desc}\n"
                except Exception as e:
                    print(f"Error parsing {specs_file}: {e}")
                    
    with open(docs_dir / "README.md", "w") as f:
        f.write(index_md)
        
    print(f"Successfully generated documentation for {len(roles)} roles in docs/")

if __name__ == "__main__":
    main()
