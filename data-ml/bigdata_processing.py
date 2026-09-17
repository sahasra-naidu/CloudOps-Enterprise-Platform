import csv
from collections import Counter

input_file = "service_requests.csv"
output_file = "request_summary.csv"

status_counts = Counter()

with open(input_file, newline="") as f:
    reader = csv.DictReader(f)
    for row in reader:
        status_counts[row["status"]] += 1

with open(output_file, "w", newline="") as f:
    writer = csv.writer(f)
    writer.writerow(["status", "request_count"])
    for status, count in status_counts.items():
        writer.writerow([status, count])

print("Big Data processing completed")
print(f"Processed records: {sum(status_counts.values())}")
print(f"Summary written to: {output_file}")
