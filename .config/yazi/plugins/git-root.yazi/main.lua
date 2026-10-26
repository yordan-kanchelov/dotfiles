local cwd = ya.sync(function()
	return tostring(cx.active.current.cwd)
end)

return {
	entry = function()
		local output = Command("git")
			:arg({ "-C", cwd(), "rev-parse", "--show-toplevel" })
			:output()
		if output and output.status.success then
			local root = output.stdout:gsub("[\r\n]+$", "")
			if root ~= "" then
				ya.emit("cd", { root })
			end
		end
	end,
}
