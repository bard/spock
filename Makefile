CFLAGS=-Inss -I/usr/include/nss/ -I/usr/include/nspr
#LDLIBS=-lnspr4 -lplds4 -lplc4 -lnss3 -lsoftokn3 -lsmime3 -lssl3
LDLIBS=-lsmime3 -lssl3
OBJS=nss/secpwd.o nss/secutil.o nss/secerror.o nss/pppolicy.o nss/moreoids.o nss_sign_data.o

all: nss_sign_data

%.o: %.c
	$(CC) -c $(CFLAGS) -o $(@) $(^)

nss_sign_data: $(OBJS)
	$(CC) -o $(@) $(OBJS) $(LDLIBS)

clean:
	rm -f *.o nss/*.o


.PHONY: all clean