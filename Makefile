
.PHONY: luacheck clean

luacheck:
	luacheck *.lua

clean:
	$(RM) $(shell find . -name '*~')
