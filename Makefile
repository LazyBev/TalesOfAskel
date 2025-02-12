.PHONY: build run clean

build:
	@odin build com.odin -file

run: 
	@odin run .

clean:
	@rm -rf com
