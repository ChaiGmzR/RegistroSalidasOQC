import pandas as pd
import requests
import math
import time

# Esperar a que el servidor esté listo
print("Esperando a que el servidor esté listo...")
time.sleep(2)

# Leer el Excel directamente
df = pd.read_excel('Modelos.xlsx')

# Convertir a lista de diccionarios
records = df.to_dict(orient='records')

# Limpiar valores NaN
def clean_value(v):
    if isinstance(v, float) and math.isnan(v):
        return None
    return v

cleaned_records = []
for r in records:
    cleaned = {k: clean_value(v) for k, v in r.items()}
    cleaned_records.append(cleaned)

print(f'Total registros a cargar: {len(cleaned_records)}')

# Enviar al endpoint de carga masiva
try:
    response = requests.post('http://localhost:3000/api/part-numbers/bulk', 
        json={'records': cleaned_records},
        headers={'Content-Type': 'application/json'},
        timeout=30)

    print(f'Status: {response.status_code}')
    print(f'Response: {response.text}')
except Exception as e:
    print(f'Error: {e}')
