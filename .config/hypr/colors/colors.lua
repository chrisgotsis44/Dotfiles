local theme = require("colors.theme_vars")
for k, v in pairs(theme) do
    _G[k] = v
end
