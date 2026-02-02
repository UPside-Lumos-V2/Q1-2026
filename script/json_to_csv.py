import os
import json
import csv
import glob

DATA_DIR = "data/verified"
OUTPUT_FILE = "data/dataset.csv"

def aggregate_data():
    # Find all JSON files in verified directory
    json_files = glob.glob(os.path.join(DATA_DIR, "*.json"))
    
    if not json_files:
        print("No verified data found to aggregate.")
        return

    # Define CSV Headers
    headers = [
        "mode", "chain_id", "block_number", "block_timestamp", 
        "gas_used", "realized_profit", "token_symbol", "token_decimals", 
        "token_address", "victim_code_size", "success"
    ]

    # Initialize list for new rows
    new_rows = []

    for file_path in json_files:
        try:
            with open(file_path, 'r') as f:
                data = json.load(f)
                
                # Create a row with default None for missing keys
                row = {header: data.get(header, None) for header in headers}
                new_rows.append(row)
        except Exception as e:
            print(f"Error reading {file_path}: {e}")

    # Read existing CSV to avoid duplicates (Optional logic could go here)
    # For now, we append. In a production system, we'd dedup based on block/tx.
    
    file_exists = os.path.isfile(OUTPUT_FILE)
    
    with open(OUTPUT_FILE, 'a', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=headers)
        
        if not file_exists:
            writer.writeheader()
            
        writer.writerows(new_rows)
        
    print(f"✅ Aggregated {len(new_rows)} records to {OUTPUT_FILE}")

if __name__ == "__main__":
    aggregate_data()
