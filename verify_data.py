import requests

r = requests.get('http://localhost:3000/api/part-numbers')
d = r.json()
print(f'Total registros: {len(d["data"])}')
print('\nPrimeros 10 números de parte:')
for p in d['data'][:10]:
    model = p["model"][:50] + "..." if p["model"] and len(p["model"]) > 50 else (p["model"] or "N/A")
    print(f'  - {p["part_number"]}: {model}')

# Verificar que EBR80757417 existe
found = [p for p in d['data'] if p['part_number'] == 'EBR80757417']
print(f'\n¿EBR80757417 existe? {"Sí" if found else "No"}')
if found:
    print(f'  Descripción: {found[0]["description"]}')
    print(f'  Modelo: {found[0]["model"]}')
