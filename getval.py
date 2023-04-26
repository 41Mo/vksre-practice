import psycopg2 as pg
import argparse

parser = argparse.ArgumentParser()
parser.add_argument("--domain", type=str)
parser.add_argument("--ip", type=str)
args = parser.parse_args()
print(args)

def connect_db():
    try:
        conn = pg.connect(database = "postgres", user = "postgres", password = "example", host = "localhost", port = "5432")
        return conn
    except:
        print("unable to connect to the database") 
        sys.exit(-1)

if not args.domain and not args.ip:
    parser.error('No arguments provided.')
    exit(0)

conn = connect_db()
cursor = conn.cursor()

if args.domain:
    cursor.execute(f"select * from blocked where url like '%{args.domain}%';")

val = cursor.fetchall()

print(val)

conn.close()
cursor.close()
