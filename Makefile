.PHONY: build run clean

build-com:
	@odin build com.odin -file

run: 
	@odin run .

clean:
	@rm -rf com
