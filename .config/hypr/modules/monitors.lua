hl.monitor({
    output = "eDP-1",
    mode = "preferred",
    position = "auto",
    scale = 1.0,
})

for i = 1, 10 do
    hl.workspace_rule({
        workspace = tostring(i),
        monitor = "eDP-1",
        persistent = true,
        default = (i==1)
    })
end

