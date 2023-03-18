----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
--! game_of_life_top.vhd
--! 
--! @todo description
--! 
--! 
----------------------------------------------------------------------------------
----------------------------------------------------------------------------------

----------------------------------------------------------------------------------
-- Libraries
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.utils_pkg.all;

use work.max7219_wrapper_pkg.all;
use work.button_handler_pkg.all;
use work.board_init_pkg.all;
use work.cells_pkg.all;

----------------------------------------------------------------------------------
-- Entity
----------------------------------------------------------------------------------

entity game_of_life_top is
    port (
        clk_i         : in  std_logic;
        rst_i         : in  std_logic;
        max7219_clk_o : out std_logic;
        max7219_din_o : out std_logic;
        max7219_csn_o : out std_logic := '1';
        buttons_i     : in std_logic_vector(num_buttons_c-1 downto 0)
    );
end entity;

----------------------------------------------------------------------------------
-- Architecture
----------------------------------------------------------------------------------

architecture behavioural of game_of_life_top is

    -- Main FSM
    type state_t is (st_reset, st_hw_init, st_board_init, st_pause, st_run_iter);
    signal state_s : state_t;
    signal mode_continuous_s : boolean;
    signal first_pause       : boolean;

    -- Buttons 
    signal buttons_evnts_s : events_arr_t;
    signal event_read_s    : std_logic_vector(work.button_handler_pkg.num_buttons_c-1 downto 0);

    -- Board init module
    signal cells_board_init : cell_array_t;
    signal board_init_cmd_s : board_init_cmd_t;

    -- Cells
    signal next_iter_s     : std_logic;
    signal next_gen_done_s : std_logic;
    signal cells_lastgen_s : cell_array_t;
    constant gen_ctr_ticks_c : integer := 1000000; -- 1M@1MHz = 1 s
    signal gen_count_s       : integer;    
    
    -- Muxs
    signal cells_mux_s : cell_array_t;

    -- max7219
    signal max7219_cmd_s      : std_logic_vector(log2_ceil(num_macro_cmds_c)-1 downto 0);
    signal max7219_done_s     : std_logic;
    signal max7219_data_all_s : std_logic_vector(num_segments_c*word_width_c - 1 downto 0);
    signal max7219_start_s    : std_logic;
    constant refresh_ticks_c  : integer := 100000; -- 100k@1MHz = 100 ms
    signal refresh_count_s    : integer;
    
begin

    -- Main FSM
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if    rst_i = '1'                                                                            then state_s <= st_reset;
            else
                case state_s is 
                    when st_reset      =>                                                                     state_s <= st_hw_init;
                    when st_hw_init    => if    (max7219_done_s = '1'                                  ) then state_s <= st_board_init ; end if;
                    when st_board_init => if    (buttons_evnts_s(buttons_ids_c.butCENTER) = long_press ) then state_s <= st_pause      ; end if;
                    when st_pause      => if    (buttons_evnts_s(buttons_ids_c.butCENTER) = short_press) then state_s <= st_run_iter;
                                          elsif (gen_count_s = 0 and mode_continuous_s                 ) then state_s <= st_run_iter;
                                          elsif (buttons_evnts_s(buttons_ids_c.butDOWN  ) = long_press ) then state_s <= st_board_init ; end if;
                    when st_run_iter   => if    (next_gen_done_s = '1' or mode_continuous_s            ) then state_s <= st_pause      ; end if;
                end case;
            end if;
        end if;
    end process;

    -- mode continuous
    process (clk_i) 
    begin
        if rising_edge(clk_i) then
            if    rst_i = '1'                                                                                         then mode_continuous_s <= false;
            elsif (state_s = st_pause or state_s = st_run_iter) and buttons_evnts_s(buttons_ids_c.butUP) = long_press then mode_continuous_s <= not mode_continuous_s;
            end if;
        end if;
    end process;
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if    state_s = st_reset              then gen_count_s <= 0;
            elsif gen_count_s < gen_ctr_ticks_c-1 then gen_count_s <= gen_count_s+1;
            else                                       gen_count_s <= 0;
            end if;
        end if;
    end process;    

    -- first pause
    process (clk_i) 
    begin
        if rising_edge(clk_i) then
            if    state_s = st_board_init                         then first_pause <= true;
            elsif state_s = st_run_iter and next_gen_done_s = '1' then first_pause <= false;
            end if;
        end if;
    end process;

    -- Buttons
    event_read_s <= (others => '1'); -- events are always read in one cycle (as soon as they are available)
    button_handler_inst : entity work.button_handler
        port map (
            clk_i           => clk_i,
            rst_i           => rst_i,
            buttons_raw_i   => buttons_i,
            buttons_evnts_o => buttons_evnts_s,
            event_read_i    => event_read_s
        );

    -- Board initialization

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if    rst_i = '1'                                                                        then board_init_cmd_s <= nop;
            elsif state_s = st_board_init and buttons_evnts_s(buttons_ids_c.butUP)     = short_press then board_init_cmd_s <= cursor_move_U;
            elsif state_s = st_board_init and buttons_evnts_s(buttons_ids_c.butDOWN)   = short_press then board_init_cmd_s <= cursor_move_D;
            elsif state_s = st_board_init and buttons_evnts_s(buttons_ids_c.butLEFT)   = short_press then board_init_cmd_s <= cursor_move_L;
            elsif state_s = st_board_init and buttons_evnts_s(buttons_ids_c.butRIGHT)  = short_press then board_init_cmd_s <= cursor_move_R;
            elsif state_s = st_board_init and buttons_evnts_s(buttons_ids_c.butCENTER) = short_press then board_init_cmd_s <= toggle_cell;
            else                                                                                          board_init_cmd_s <= nop;
            end if;
        end if;
    end process;

    board_init_inst : entity work.board_init
        port map (
            clk_i       => clk_i,
            rst_i       => rst_i,
            cmd_i       => board_init_cmd_s,
            board_arr_o => cells_board_init
        );
        
    -- Cells
    next_iter_s <= '1' when state_s = st_run_iter else '0';
    cells_inst : entity work.cells
        port map (
            clk_i         => clk_i,
            rst_i         => rst_i,
            next_iter_i   => next_iter_s,
            cells_arr_i   => cells_mux_s,
            done_o        => next_gen_done_s,
            cells_arr_o   => cells_lastgen_s
        );

    -- Mux (select between cells and board_init)
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if (first_pause) then cells_mux_s <= cells_board_init;
            else                  cells_mux_s <= cells_lastgen_s;
            end if;
        end if;
    end process;

    -- max7219
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if    state_s = st_reset                  then refresh_count_s <= 0;
            elsif refresh_count_s < refresh_ticks_c-1 then refresh_count_s <= refresh_count_s+1;
            else                                           refresh_count_s <= 0;
            end if;
        end if;
    end process;
    process (state_s, refresh_count_s)
    begin
        max7219_start_s <= '0';
        if    state_s = st_hw_init and max7219_done_s = '1' then max7219_start_s <= '1';
        elsif refresh_count_s = 0 and max7219_done_s = '1'  then max7219_start_s <= '1';
        end if;
    end process;
    max7219_cmd_s <= "00" when (state_s = st_reset or state_s = st_hw_init) else "01"; -- initialize during reset. @todo: replace macro_cmd_i input type by max7219_macro_cmd_t type and use commands instead of "00" or "01"
    max7219_data_all_s <= cells_array_to_slv(cells_mux_s);
    max7219_wrapper_inst : entity work.max7219_wrapper
        port map (
            clk_i            => clk_i,
            rst_i            => rst_i,
            macro_cmd_i      => max7219_cmd_s,
            data_all_i       => max7219_data_all_s,
            addr_i           => (others => '0'),
            data_i           => (others => '0'),
            start_i          => max7219_start_s,
            macro_cmd_done_o => max7219_done_s,
            max7219_clk_o    => max7219_clk_o,
            max7219_din_o    => max7219_din_o,
            max7219_csn_o    => max7219_csn_o
        );

end architecture;
