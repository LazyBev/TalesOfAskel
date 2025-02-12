.PHONY: build run clean

build:
	@odin build toa.odin -file

run: 
	@odin run .

clean:
	@rm -rf toa
