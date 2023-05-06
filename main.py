#%%
import psycopg2 as pg

import csv 
import sys
import ipaddress
import os
import glob
import argparse
import urllib.parse as urllibparse
parser = argparse.ArgumentParser()
parser.add_argument("--create-db-scheme", action="store_true")
args = parser.parse_args()

csv.field_size_limit(sys.maxsize)

csvFilePath = 'dump.csv'

dbname='admini'

def connect_db():
    try:
        conn = pg.connect(database = "admini", user = "admini", password = "toortoor", host = "79.137.157.25", port = "5432")
        return conn
    except Exception as e:
        print("unable to connect to the database") 
        raise e
        sys.exit(-1)

def maxlen(arr):
    for i in arr[0]:
        ld = (max(arr, key=lambda e: e[max(e, key=lambda k: len(str(e[i])) if e[i] is not None else 0) ]))
        print(f"Longest {i} is ", len(str(ld[i])))



def import_file(filename):
    with open(filename, 'r', encoding='cp1251') as csv_file:
        lines = csv_file.readlines()
        print(f"Csv lines, {len(lines)}")
        inserts = []
        inserted = 0
        for line in lines:
            components = line.strip().split(';')
            if len(components) < 6:
                continue

            ips = components[0].split('|')
            domain = components[1]
            url = components[2].strip('"')
            decision_org = components[3]
            decision_num = components[4]
            decision_date = components[5]

            if domain.strip() == '':
                domain = ''

            if url.strip() == '' or url == 'http://' or url == 'https://':
                url = ''

            for ip in ips:
                if ip.strip() == '':
                    if domain is not None and len(domain.split('.')) == 4:
                        ip = domain
                    else:
                        ip = None

                ip_first = ''
                ip_last = ''
                length = 0
                if ip is not None:
                    pair = ip.split('/')
                    ip_first = ipaddress.ip_address(pair[0])
                    # Skip ipv6.
                    if ip_first.version == 6:
                        continue
                    if len(pair) > 1:
                        length = int(pair[1])
                        ip_last = ipaddress.ip_address(int(ip_first) | (1 << (32 - length)) - 1)
                    else:
                        length = 32
                        ip_last = ip_first

                    for u in url.split('|'):
                        inserts.append({
                            'ip': ip,
                            'ip_first': format(ip_first),
                            'ip_last': format(ip_last),
                            'length': length,
                            'decision_date': decision_date,
                            'decision_org': decision_org,
                            'decision_num': decision_num,
                            'domain':  domain,
                            'url': urllibparse.quote(u.strip(), safe=''),
                        })
                        inserted += 1
                else:
                    ip = ''
        return inserts


if args.create_db_scheme:
    conn = connect_db()
    cur = conn.cursor()
    try:
        cur.execute("DROP TABLE blocked;")
        conn.commit() # <--- makes sure the change is shown in the database
    except Exception as e:
        print(e)
        print("can't drop table!")

    try:
        cur.execute("CREATE TABLE blocked (ip varchar(18), ip_first varchar(16), ip_last varchar(16), length varchar(20), decision_date varchar(1024), decision_org varchar(1024), decision_num varchar(1024), domain varchar(1024), url varchar(10000));")
    except:
        print("can't drop database!")
        sys.exit(0)
    conn.commit() # <--- makes sure the change is shown in the database
    conn.close()
    cur.close()
    print("db succesfully created")
    sys.exit(0)

parsed = import_file("dump.csv")

listoftuples = []
for e in parsed:
    listoftuples.append(tuple(e.values()))

conn = connect_db()
cursor = conn.cursor()
print("insert to db")
#for d in parsed:
try:
    cursor.executemany("INSERT INTO blocked(ip, ip_first, ip_last, length, decision_date, decision_org, decision_num, domain, url) VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s)", listoftuples)
except Exception as e:
    raise
    sys.exit(0)

print("exec many ok!")
#try:
#cur.executemany(SQL_INSERT, parsed)
#except:
    #print("cant push data")

conn.commit() # <--- makes sure the change is shown in the database
conn.close()
cursor.close()
exit(0)
