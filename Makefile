.PHONY: build run clean

build-game:
	@odin build main.odin -file

build-com:
	@odin build com.odin -file

run: 
	@odin run .

clean:
	@rm -rf game
