library ieee;
use ieee.std_logic_1164.all;

entity tb_clock_divider is
end entity tb_clock_divider;

architecture sim of tb_clock_divider is

    constant CLK_PERIOD : time := 10 ns;  -- 100 MHz Simulations-Takt
    constant DIVISOR    : positive := 10;

    signal clk_in  : std_logic := '0';
    signal rst     : std_logic := '1';
    signal clk_out : std_logic;

begin

    -- DUT
    dut : entity work.clock_divider
        generic map (DIVISOR => DIVISOR)
        port map (
            clk_in  => clk_in,
            rst     => rst,
            clk_out => clk_out
        );

    -- Taktgenerator
    clk_in <= not clk_in after CLK_PERIOD / 2;

    -- Stimuli
    stim : process
    begin
        -- Reset fuer 3 Takte halten
        wait for CLK_PERIOD * 3;
        rst <= '0';

        -- 200 Takte laufen lassen (= 20 clk_out-Perioden)
        wait for CLK_PERIOD * 200;

        report "Simulation beendet." severity note;
        std.env.stop;
    end process;

end architecture sim;
