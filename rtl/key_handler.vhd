----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
--! key_handler.vhd
--! 
--! Module in charge of receiving and processing key events via AXIS
----------------------------------------------------------------------------------
----------------------------------------------------------------------------------

----------------------------------------------------------------------------------
-- Internal package
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
package key_handler_pkg is

    constant num_keys_c : positive := 9;
    type keys_ids_t is record 
        key_esc        : integer;
        key_up         : integer;
        key_down       : integer;
        key_left       : integer;
        key_right      : integer;
        key_space      : integer;
        key_c          : integer;        
        key_enter      : integer;
        key_backspace  : integer;
    end record;
    constant keys_ids_c : keys_ids_t := (key_esc => 0, key_up => 1, key_down => 2, key_left => 3, key_right => 4, key_space => 5, key_c => 6, key_enter => 7, key_backspace => 8);

    type released_t is array (num_keys_c-1 downto 0) of boolean;

    type event_t is (no_event, pressed);
    type events_arr_t is array (num_keys_c-1 downto 0) of event_t;

end package;

----------------------------------------------------------------------------------
-- Libraries
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.key_handler_pkg.all;

----------------------------------------------------------------------------------
-- Entity
----------------------------------------------------------------------------------

entity key_handler is
    port (
        clk_i           : in  std_logic;
        rst_i           : in  std_logic;
        s_axis_tready   : out std_logic;
        s_axis_tvalid   : in  std_logic;
        s_axis_tdata    : in  std_logic_vector(32-1 downto 0);
        s_axis_tlast    : in  std_logic;
        s_axis_tuser    : in  std_logic;
        keys_evnts_o    : out events_arr_t;
        event_read_i    : in  std_logic_vector(num_keys_c-1 downto 0)
    );
end entity;

----------------------------------------------------------------------------------
-- Architecture
----------------------------------------------------------------------------------

architecture behavioural of key_handler is

    signal s_axis_consumed  : std_logic;
    signal key_id_reg       : integer;
    signal event_is_pending : std_logic;
    signal clear_events     : std_logic;

begin

    s_axis_tready <= '1'; -- Overwrite always last data received
    s_axis_consumed <= s_axis_tready and s_axis_tvalid;
    clear_events <= '1' when (to_integer(unsigned(event_read_i)) /= 0) else '0';

    -- Only one key event is expected at a time, so AXIS should carry a single-word line.
    -- For simplicity, only last word is taken
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if (rst_i = '1') then
                key_id_reg <= 0;
                event_is_pending <= '0';
            elsif (s_axis_consumed = '1' and s_axis_tlast = '1') then
                key_id_reg <= to_integer(unsigned(s_axis_tdata));
                event_is_pending <= '1';
            elsif (clear_events = '1') then
                event_is_pending <= '0';
            end if;
        end if;
    end process;

    -- Set events
    proc_detect_event : process (clk_i)
    begin
        if rising_edge(clk_i) then
            if    (rst_i = '1'           ) then keys_evnts_o             <= (others => no_event);
            elsif (event_is_pending = '1') then keys_evnts_o(key_id_reg) <= pressed;
            elsif (clear_events = '1'    ) then keys_evnts_o             <= (others => no_event);
            end if;
        end if;
    end process;

end architecture;
