library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity blinky is
    generic (
        DIVISOR : positive := 6_000_000
    );
    port (
        clk : in  std_logic;
        led : out std_logic
    );
end entity blinky;

architecture rtl of blinky is
    signal counter : integer range 0 to DIVISOR/2 - 1 := 0;
    signal led_reg : std_logic := '0';
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if counter = DIVISOR/2 - 1 then
                counter <= 0;
                led_reg <= not led_reg;
            else
                counter <= counter + 1;
            end if;
        end if;
    end process;

    led <= led_reg;
end architecture rtl;
