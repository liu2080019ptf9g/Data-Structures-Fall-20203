#!/usr/local/bin/python

#grep "COST TIME MICRO SECS" error.log | awk '{print $17}' | /usr/local/openresty/shell_scripts/cma.py 

import sys


limit = 500

if len(sys.argv) > 1 :
    limit = int(sys.argv[1])

cma = 0
count = 0
total_count = 0

for line in sys.stdin:
    total_count = total_count + 1
    line = line.replace(',','')
    value = int(line)
    if (value > limit): 
        #print ("value is %d"%(value))
        cma = (value + cma * count ) / (count + 1)
        count = count + 1
        #print ("cma is %d"%(cma))
    
print ("Average is %d, count is %d, total_count is %d, %% %d"%(cma,count,total_count,(count*100/total_count)))