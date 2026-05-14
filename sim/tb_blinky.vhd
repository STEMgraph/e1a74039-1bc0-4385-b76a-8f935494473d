library ieee;
use ieee.std_logic_1164.all;

entity tb_blinky is
end entity tb_blinky;

architecture sim of tb_blinky is

    constant CLK_PERIOD : time     := 83333 ps;  -- ~12 MHz (83.333 ns)
    constant DIVISOR    : positive := 10;         -- keep small; hardware uses 6_000_000

    signal clk : std_logic := '0';
    signal led : std_logic;

begin

    dut : entity work.blinky
        generic map (DIVISOR => DIVISOR)
        port map (
            clk => clk,
            led => led
        );

    clk <= not clk after CLK_PERIOD / 2;

    stim : process
    begin
        -- 200 cycles = 20 complete LED periods at DIVISOR=10
        wait for CLK_PERIOD * 200;
        report "Simulation complete." severity note;
        std.env.stop;
    end process;

end architecture sim;
