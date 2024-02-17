----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
--! game_of_life.vhd
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

use work.key_handler_pkg.all;
use work.board_init_pkg.all;
use work.cells_pkg.all;

----------------------------------------------------------------------------------
-- Entity
----------------------------------------------------------------------------------

entity game_of_life is
    generic (
        ratio_expansion_c    : positive := 40; -- should be an integer so that frame_resolution = board_size * ratio_expansion_c (e.g. for 40 and 1280x720: 720 = 18 * 40, 1280 = 32 * 40)
        pixel_width_c        : positive := 24
    );
    port (
        clk_i         : in  std_logic;
        rst_i         : in  std_logic;
        s_axis_tready : out std_logic;
        s_axis_tvalid : in  std_logic;
        s_axis_tdata  : in  std_logic_vector(32-1 downto 0);
        s_axis_tlast  : in  std_logic;
        s_axis_tuser  : in  std_logic;
        m_axis_tready : in  std_logic;
        m_axis_tvalid : out std_logic;
        m_axis_tdata  : out std_logic_vector(pixel_width_c-1 downto 0);
        m_axis_tlast  : out std_logic;
        m_axis_tuser  : out std_logic        
    );
end entity;

----------------------------------------------------------------------------------
-- Architecture
----------------------------------------------------------------------------------

architecture behavioural of game_of_life is

    -- Main FSM
    type state_t is (st_reset, st_board_init, st_pause, st_run_iter);
    signal state_s : state_t;
    signal mode_continuous_s : boolean;
    signal first_pause       : boolean;

    -- Keys 
    signal keys_evnts_s : events_arr_t;
    signal event_read_s    : std_logic_vector(work.key_handler_pkg.num_keys_c-1 downto 0);

    -- Board init module
    signal cells_board_init : cell_array_t;
    signal cells_blinky_s   : cell_array_t;
    signal board_init_cmd_s : board_init_cmd_t;

    -- Cells
    signal next_iter_s     : std_logic;
    signal next_gen_done_s : std_logic;
    signal cells_lastgen_s : cell_array_t;
    -- constant one_s_max_c : integer := 1000000; -- 1M@1MHz = 1 s
    constant one_s_max_c : integer := 150000000; -- 150M@300MHz = 0.5 s
    signal one_s_count_s     : integer; -- Used to trigger a new generation
    
    -- Muxs
    signal cells_mux_s  : cell_array_t;
    signal cells_mux2_s : cell_array_t;

    -- Video
    signal video_done_s     : std_logic;
    signal video_start_s    : std_logic;
    -- constant refresh_ticks_c  : integer := 100000; -- 100k@1MHz = 100 ms
    constant refresh_ticks_c  : integer := 15000000; -- 30000k@300MHz = 50 ms
    signal refresh_count_s    : integer; -- Used to refresh the cells board within a same generation (mainly for when it is blinking)
    
begin

    -- Main FSM
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if    rst_i = '1'                                                                      then state_s <= st_reset;
            else
                case state_s is 
                    when st_reset      =>                                                               state_s <= st_board_init;
                    when st_board_init => if    (keys_evnts_s(keys_ids_c.key_enter) = pressed    ) then state_s <= st_pause      ; end if;
                    when st_pause      => if    (keys_evnts_s(keys_ids_c.key_space) = pressed    ) then state_s <= st_run_iter;
                                          elsif (one_s_count_s = 0 and mode_continuous_s         ) then state_s <= st_run_iter;
                                          elsif (keys_evnts_s(keys_ids_c.key_backspace) = pressed) then state_s <= st_board_init ; end if;
                    when st_run_iter   => if    (next_gen_done_s = '1' or mode_continuous_s      ) then state_s <= st_pause      ; end if;
                end case;
            end if;
        end if;
    end process;

    -- mode continuous
    process (clk_i) 
    begin
        if rising_edge(clk_i) then
            if    rst_i = '1'                                                                                then mode_continuous_s <= false;
            elsif (state_s = st_pause or state_s = st_run_iter) and keys_evnts_s(keys_ids_c.key_c) = pressed then mode_continuous_s <= not mode_continuous_s;
            end if;
        end if;
    end process;

    -- 1-second timer (for timing between generations in continuous mode and for blinky output during board init)
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if    state_s = st_reset            then one_s_count_s <= 0;
            elsif one_s_count_s < one_s_max_c-1 then one_s_count_s <= one_s_count_s+1;
            else                                     one_s_count_s <= 0;
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

    -- Keys
    event_read_s <= (others => '1'); -- events are always read in one cycle (as soon as they are available)
    key_handler_inst : entity work.key_handler
        port map (
            clk_i           => clk_i,
            rst_i           => rst_i,
            s_axis_tready   => s_axis_tready,
            s_axis_tvalid   => s_axis_tvalid,
            s_axis_tdata    => s_axis_tdata,
            s_axis_tlast    => s_axis_tlast,
            s_axis_tuser    => s_axis_tuser,
            keys_evnts_o    => keys_evnts_s,
            event_read_i    => event_read_s
        );

    -- Board initialization

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if    rst_i = '1'                                                              then board_init_cmd_s <= nop;
            elsif state_s = st_board_init and keys_evnts_s(keys_ids_c.key_up)    = pressed then board_init_cmd_s <= cursor_move_U;
            elsif state_s = st_board_init and keys_evnts_s(keys_ids_c.key_down)  = pressed then board_init_cmd_s <= cursor_move_D;
            elsif state_s = st_board_init and keys_evnts_s(keys_ids_c.key_left)  = pressed then board_init_cmd_s <= cursor_move_L;
            elsif state_s = st_board_init and keys_evnts_s(keys_ids_c.key_right) = pressed then board_init_cmd_s <= cursor_move_R;
            elsif state_s = st_board_init and keys_evnts_s(keys_ids_c.key_space) = pressed then board_init_cmd_s <= toggle_cell;
            else                                                                                board_init_cmd_s <= nop;
            end if;
        end if;
    end process;

    board_init_inst : entity work.board_init
        generic map (
            one_s_max_c  => one_s_max_c
        ) port map (
            clk_i        => clk_i,
            rst_i        => rst_i,
            cmd_i        => board_init_cmd_s,
            board_arr_o  => cells_board_init,
            blinky_arr_o => cells_blinky_s,
            count_i      => to_unsigned(one_s_count_s, log2_ceil(one_s_max_c))
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

    -- Mux (select between blinky output (during board init) and normal output)
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if (state_s = st_board_init) then cells_mux2_s <= cells_blinky_s;
            else                              cells_mux2_s <= cells_mux_s;
            end if;
        end if;
    end process;

    -- Video output

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if    state_s = st_reset                  then refresh_count_s <= 0;
            elsif refresh_count_s < refresh_ticks_c-1 then refresh_count_s <= refresh_count_s+1;
            else                                           refresh_count_s <= 0;
            end if;
        end if;
    end process;

    process (refresh_count_s, video_done_s)
    begin
        if refresh_count_s = 0 and video_done_s = '1'  then video_start_s <= '1';
        else                                                video_start_s <= '0';
        end if;
    end process;

    board_to_frame_inst : entity work.board_to_frame
        generic map (
            board_rows_c        => num_rows_c,
            board_cols_c        => num_cols_c,
            ratio_expansion_c   => ratio_expansion_c,
            pixel_width_c       => pixel_width_c
        )
        port map (
            clk_i           => clk_i,
            rst_i           => rst_i,
            data_all_i      => cells_array_to_slv(cells_mux2_s),
            start_i         => video_start_s,
            done_o          => video_done_s,
            m_axis_tready   => m_axis_tready,
            m_axis_tvalid   => m_axis_tvalid,
            m_axis_tdata    => m_axis_tdata,
            m_axis_tlast    => m_axis_tlast,
            m_axis_tuser    => m_axis_tuser
        );

end architecture;
