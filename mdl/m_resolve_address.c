#include <sys/socket.h>
#include <stdio.h>
#include <netdb.h>
#include <string.h> 
#include <unistd.h> 
#include <stdlib.h>
#include <arpa/inet.h>

int32_t ResolveAddress_IPv6(const char *host, char *remote_address);

int32_t ResolveAddress_IPv6(const char *host, char *remote_address)
{
	struct 		addrinfo *result;
	struct 		addrinfo hints;
	int 		error;		
	char		*ptr_address;

	ptr_address = remote_address + 1;

	// Let's get the Ipv6 address if it exists
	memset (&hints, 0, sizeof(hints));

	hints.ai_family = AF_INET6; 		
	hints.ai_socktype = SOCK_STREAM;

	error = getaddrinfo(&host[1], 0, &hints, &result);

	if (error == 0) {
		inet_ntop(AF_INET6, &(((struct sockaddr_in6 *)(result->ai_addr))->sin6_addr), ptr_address, INET6_ADDRSTRLEN);
		*remote_address = (char) strlen(ptr_address);
		freeaddrinfo(result);
		return AF_INET6;
	}

	// Nope, Let us check for an ipv4 address

	memset (&hints, 0, sizeof(hints));

	hints.ai_family = AF_INET; 		
	hints.ai_socktype = SOCK_STREAM;

	error = getaddrinfo(&host[1], 0, &hints, &result);

	if (error == 0) {
   		inet_ntop(AF_INET, &(((struct sockaddr_in *)(result->ai_addr))->sin_addr), ptr_address, INET6_ADDRSTRLEN);
		*remote_address = (char) strlen(ptr_address);
		freeaddrinfo(result);
		return AF_INET;
	}

	remote_address = 0;
	return 0;
}

