return {
  'MeanderingProgrammer/render-markdown.nvim',
  ft = { 'markdown' },
  dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' },
  opts = {
    render_modes = { 'n', 'v', 'c' },
    heading = { enabled = false },
    link = { enabled = false },
    anti_conceal = { enabled = false },
  },
}
