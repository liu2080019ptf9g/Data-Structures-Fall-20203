#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <uuid/uuid.h>

//yum -y install libuuid-devel
//libuuid-1.0.3.tar.gz

static char chars[] = { 
	'a','b','c','d','e','f','g','h',  
	'i','j','k','l','m','n','o','p',  
	'q','r','s','t','u','v','w','x',  
	'y','z','0','1','2','3','4','5',  
	'6','7','8','9','A','B','C','D',  
	'E','F','G','H','I','J','K','L',  
	'M','N','O','P','Q','R','S','T',  
	'U','V','W','X','Y','Z' 
}; 

void uuid(char *result, int len)
{
	unsigned char uuid[16];
	char output[24];
	const char *p = (const char*)uuid;

	uuid_generate(uuid);
	memset(output, 0, sizeof(output));

	int i, j;
	for (j = 0; j < 2; j++)
	{
		unsigned long long v = *(unsigned long long*)(p + j*8);
		int begin = j * 10;
		int end =  begin + 10;

		for (i = begin; i < end; i++)
		{
			int idx = 0X3D & v;
			output[i] = chars[idx];
			v = v >> 6;
		}
	}

	len = (len > sizeof(output)) ? sizeof(output) :  len;
	memcpy(result, output, len);
}

void uuid8(char *result) 
{
	uuid(result, 8);
	result[8] = '\0';
}

void uuid20(char *result) 
{
	uuid(result, 20);
	result[20] = '\0';
}

void uuid32(char *result)
{
    uuid_t uuid;
    uuid_generate(uuid);
    uuid_unparse(uuid, result);
    result[36] = '\0';
}

