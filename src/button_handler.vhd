----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
--! button_handler.vhd
--! 
--! Module in charge of 1) receiving buttons signals, 2) getting rid of metastability 
--! (sync), 3) debouncing and 4) detect none/short/long events

----------------------------------------------------------------------------------
----------------------------------------------------------------------------------

----------------------------------------------------------------------------------
-- Internal package
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
package button_handler_pkg is

    constant num_buttons_c : positive := 5;
    type buttons_ids_t is record 
        butCENTER : integer;
        butUP     : integer;
        butDOWN   : integer;
        butLEFT   : integer;
        butRIGHT  : integer;
    end record;
    constant buttons_ids_c : buttons_ids_t := (butCENTER => 0, butUP => 1, butDOWN => 2, butLEFT => 3, butRIGHT => 4);
    type buttons_sync_t is array (num_buttons_c-1 downto 0) of std_logic_vector(1 downto 0);
    type buttons_sync_last_t is array (num_buttons_c-1 downto 0) of std_logic; -- Register for buttons_sync(last)

    constant freq_khz_c              : real := 1000.0;
    constant period_debounce_ms_c    : real := 50.0;
    constant period_long_ms_c        : real := 2000.0;
    constant period_debounce_ticks_c : positive := integer( (period_debounce_ms_c/1000.0) / (1.0/(freq_khz_c*1000.0)) ) ;
    constant period_long_ticks_c     : positive := integer( (period_long_ms_c/1000.0) / (1.0/(freq_khz_c*1000.0)) );
    type counter_pressed_t is array (num_buttons_c-1 downto 0) of integer range 0 to period_long_ticks_c;
    type released_t is array (num_buttons_c-1 downto 0) of boolean;

    type event_t is (no_event, short_press, long_press);
    type events_arr_t is array (num_buttons_c-1 downto 0) of event_t;

end package;

----------------------------------------------------------------------------------
-- Libraries
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.button_handler_pkg.all;

----------------------------------------------------------------------------------
-- Entity
----------------------------------------------------------------------------------

entity button_handler is
    port (
        clk_i           : in  std_logic;
        rst_i           : in  std_logic;
        buttons_raw_i   : in  std_logic_vector(num_buttons_c-1 downto 0);
        buttons_evnts_o : out events_arr_t;
        event_read_i    : in  std_logic_vector(num_buttons_c-1 downto 0)
    );
end entity;

----------------------------------------------------------------------------------
-- Architecture
----------------------------------------------------------------------------------

architecture behavioural of button_handler is

    signal buttons_sync_s      : buttons_sync_t;
    signal buttons_sync_last_s : buttons_sync_last_t;
    signal counter_pressed_s   : counter_pressed_t;
    signal released_s          : released_t;

begin

    -- 2-stage sync (for metastability)

    proc_but_sync : process (clk_i)
    begin
        for i in 0 to num_buttons_c-1 loop
            if rising_edge(clk_i) then
                if rst_i = '1' then
                    buttons_sync_s(i)(0)   <= '0';
                    buttons_sync_s(i)(1)   <= '0';
                    buttons_sync_last_s(i) <= '0';
                else
                    buttons_sync_s(i)(0)   <= buttons_raw_i(i);
                    buttons_sync_s(i)(1)   <= buttons_sync_s(i)(0);
                    buttons_sync_last_s(i) <= buttons_sync_s(i)(1);
                end if;
            end if;
        end loop;
    end process;

    proc_button_released : process (all)
    begin
        for i in 0 to num_buttons_c-1 loop
            released_s(i) <= (buttons_sync_s(i)(1) = '0' and buttons_sync_last_s(i) = '1');
        end loop;
    end process;

    -- Counter for press duration
    proc_press_duration : process (clk_i)
    begin
        for i in 0 to num_buttons_c-1 loop
            if rising_edge(clk_i) then
                if    (rst_i = '1' or buttons_sync_s(i)(1) = '0')                                  then counter_pressed_s(i) <= 0;
                elsif (buttons_sync_s(i)(1) = '1' and counter_pressed_s(i) < period_long_ticks_c ) then counter_pressed_s(i) <= counter_pressed_s(i) + 1;
                end if;
            end if;
        end loop;
    end process;

    -- Detect events
    proc_detect_event : process (clk_i)
    begin
        for i in 0 to num_buttons_c-1 loop
            if rising_edge(clk_i) then
                if    (rst_i = '1')                                        then buttons_evnts_o(i) <= no_event;
                elsif (released_s(i)) then 
                    if    (counter_pressed_s(i) < period_debounce_ticks_c) then buttons_evnts_o(i) <= no_event;
                    elsif (counter_pressed_s(i) < period_long_ticks_c    ) then buttons_evnts_o(i) <= short_press;
                    else                                                        buttons_evnts_o(i) <= long_press;
                    end if;
                elsif (event_read_i(i) = '1')                              then buttons_evnts_o(i) <= no_event;
                end if;
            end if;
        end loop;
    end process;

end architecture;
