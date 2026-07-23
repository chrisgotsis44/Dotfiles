return {
    <* for name, value in colors *>
    {{name}} = "rgb({{value.default.hex_stripped}})",
    <* endfor *>
    -- Compatibility with custom themes
    bg0 = "rgb({{colors.surface_container_lowest.default.hex_stripped}})",
    bg1 = "rgb({{colors.surface_container_low.default.hex_stripped}})",
    bg2 = "rgb({{colors.surface_container.default.hex_stripped}})",
    bg3 = "rgb({{colors.surface_container_high.default.hex_stripped}})",
    bg4 = "rgb({{colors.surface_container_highest.default.hex_stripped}})",

    fg = "rgb({{colors.on_surface.default.hex_stripped}})",

    red = "rgb({{colors.error.default.hex_stripped}})",
    orange = "rgb({{colors.tertiary.default.hex_stripped}})",
    yellow = "rgb({{colors.primary_fixed.default.hex_stripped}})",
    green = "rgb({{colors.secondary.default.hex_stripped}})",
    aqua = "rgb({{colors.primary_container.default.hex_stripped}})",
    blue = "rgb({{colors.primary.default.hex_stripped}})",
    purple = "rgb({{colors.inverse_primary.default.hex_stripped}})",

    grey0 = "rgb({{colors.outline.default.hex_stripped}})",
    grey1 = "rgb({{colors.outline_variant.default.hex_stripped}})",
    grey2 = "rgb({{colors.on_surface_variant.default.hex_stripped}})",
}
