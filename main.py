#%%
import psycopg2 as pg
import pandas as pd

import csv 
import json 
import sys

import ipaddress
import os
import glob

#%%

csv.field_size_limit(sys.maxsize)

csvFilePath = 'dump.csv'

array = []
with open(csvFilePath, encoding='cp1251') as csvf: 
    #load csv file data using csv library's dictionary reader
    csvReader = csv.DictReader(csvf) 

    #convert each csv row into python dict
    for row in csvReader: 
        #add this python dict to json array
        array.append(row)

#%%
i:dict
for d in array:
    for k, v in d.items():
        try:
            parsed = list(filter(lambda x: len(x) > 0, v.split(';')))
            ip = parsed[0].split('|')
            if len(ip) > 1:
                print(ip)
        except AttributeError:
            continue

#%%
def import_file(filename):
    with open(filename, 'r', encoding='cp1251') as csv_file:
        lines = csv_file.readlines()
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
                domain = None

            if url.strip() == '' or url == 'http://' or url == 'https://':
                url = None

            for ip in ips:
                if ip.strip() == '':
                    if domain is not None and len(domain.split('.')) == 4:
                        ip = domain
                    else:
                        ip = None

                ip_first = None
                ip_last = None
                length = None
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

                inserts.append({
                    'ip': ip,
                    'ip_first': format(ip_first),
                    'ip_last': format(ip_last),
                    'length': length,
                    'decision_date': decision_date,
                    'decision_org': decision_org,
                    'decision_num': decision_num,
                    'domain': domain,
                    'url': url,
                })
        return inserts

#%%
import_file("dump.csv")
#%%

cur.execute(f"CREATE INSERT ")
#%%
try:
    conn = pg.connect(database = "postgres", user = "postgres", password = "example", host = "localhost", port = "5432")
except:
    print("I am unable to connect to the database") 

cur = conn.cursor()
try:
    cur.execute("CREATE TABLE blocked (id int, ip varchar(255), judgment varchar(255));")
except:
    print("I can't drop our test database!")

conn.commit() # <--- makes sure the change is shown in the database
conn.close()
cur.close()