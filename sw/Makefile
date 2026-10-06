CC ?= cc
CFLAGS ?= -std=c11 -O2 -Wall -Wextra -Werror
.PHONY: test clean
test: frodokem_pio test_pio_host test_random_host
	./test_pio_host
	./test_random_host ../vectors/random_1000.bin
frodokem_pio: frodokem_pio.c frodokem_pio_driver.c frodokem_pio_driver.h frodokem_random.h frodokem_kat_vectors.h
	$(CC) $(CFLAGS) frodokem_pio.c frodokem_pio_driver.c -o $@
test_pio_host: ../_agent/tests/test_pio_host.c frodokem_pio_driver.c frodokem_pio_driver.h
	$(CC) $(CFLAGS) -I. ../_agent/tests/test_pio_host.c frodokem_pio_driver.c -o $@
test_random_host: ../_agent/tests/test_random_host.c frodokem_pio.c frodokem_random.h
	$(CC) $(CFLAGS) -I. ../_agent/tests/test_random_host.c -o $@
clean:
	rm -f frodokem_pio test_pio_host test_random_host
