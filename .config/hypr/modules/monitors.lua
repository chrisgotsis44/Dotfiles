hl.monitor({
    output = "DP-1",
    mode = "2560x1440@239.97",
    position = "2560x0",
    scale = 1.0,
    vrr = 2
})
hl.monitor({
    output = "HDMI-A-1",
    mode = "2560x1440@144.0",
    position = "0x0",
    scale = 1.0
})

for i = 1, 5 do
    hl.workspace_rule({
        workspace = tostring(i),
        monitor = "DP-1",
        persistent = true,
        default = (i==1)
    })
end

for i = 6, 10 do
    hl.workspace_rule({
        workspace = tostring(i),
        monitor = "HDMI-A-1",
        persistent = true,
        default = (i==6)
    })
end
