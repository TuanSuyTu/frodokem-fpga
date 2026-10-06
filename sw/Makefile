CC ?= cc
CFLAGS ?= -std=c11 -O2 -Wall -Wextra -Werror
.PHONY: test clean
test: test_driver_host test_linux_backend FPGA_Driver.o frodokem_petalinux
	./test_driver_host
	./test_linux_backend
test_driver_host: test_driver_host.c frodokem_driver.c frodokem_driver.h
	$(CC) $(CFLAGS) test_driver_host.c frodokem_driver.c -o $@
FPGA_Driver.o: FPGA_Driver.c FPGA_Driver.h frodokem_driver.h
	$(CC) $(CFLAGS) -c FPGA_Driver.c -o $@
frodokem_petalinux: frodokem_petalinux.c FPGA_Driver.o frodokem_driver.c frodokem_kat_vectors.h
	$(CC) $(CFLAGS) frodokem_petalinux.c FPGA_Driver.o frodokem_driver.c -o $@
test_linux_backend: test_linux_backend.c FPGA_Driver.o
	$(CC) $(CFLAGS) test_linux_backend.c FPGA_Driver.o -o $@
clean:
	rm -f test_driver_host test_linux_backend frodokem_petalinux FPGA_Driver.o
