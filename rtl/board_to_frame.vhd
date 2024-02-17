----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
--! board_to_frame.vhd
--! 
--! Maps from the cell space (board) to the frame space (taking 1 bit each pixel).
--! Provides frame as AXIS
--! 
--! - data_all_i: contains an array representing the whole cell board (binary: alive or dead).
--! It is registered before starting operating so the input does not need to remain valid afterwards.
--! - start_i: indicates that data_all_i is valid so that it starts getting processed
--! - done_o: indicates this module has finished processing and forwarding the current data
--! - m_axis_*: transmits the data as an AXI stream, where tdata represents the logic
--! state (dead or alive), tlast represents the end of the current frame row (eol) and
--! tuser represents the beginning of a new frame (sof)
----------------------------------------------------------------------------------
----------------------------------------------------------------------------------

----------------------------------------------------------------------------------
-- Libraries
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.utils_pkg.all;

----------------------------------------------------------------------------------
-- Entity
----------------------------------------------------------------------------------

entity board_to_frame is
    generic (
        board_rows_c         : positive := 18;
        board_cols_c         : positive := 32;
        ratio_expansion_c    : positive := 40; -- should be an integer so that frame_resolution = board_size * ratio_expansion_c (e.g. for 40 and 1280x720: 720 = 18 * 40, 1280 = 32 * 40)
        pixel_width_c        : positive := 24
    );

    port (
        clk_i            : in  std_logic;
        rst_i            : in  std_logic;
        data_all_i       : in  std_logic_vector(board_rows_c*board_cols_c-1 downto 0);
        start_i          : in  std_logic;
        done_o           : out std_logic;
        m_axis_tready    : in  std_logic;
        m_axis_tvalid    : out std_logic;
        m_axis_tdata     : out std_logic_vector(pixel_width_c-1 downto 0);
        m_axis_tlast     : out std_logic;
        m_axis_tuser     : out std_logic
    );
end entity;

----------------------------------------------------------------------------------
-- Architecture
----------------------------------------------------------------------------------

architecture behavioural of board_to_frame is

    -- Video resolution
    constant frame_resolution_h_c : positive := board_cols_c * ratio_expansion_c;
    constant frame_resolution_v_c : positive := board_rows_c * ratio_expansion_c;
    
    -- FSM
    type state_t is (st_reset, st_wait_for_start, st_forward);
    signal state_s : state_t;

    -- Counters
    signal board_row_count_s : integer range 0 to board_rows_c-1;
    signal board_col_count_s : integer range 0 to board_cols_c-1;
    signal frame_row_count_s : integer range 0 to frame_resolution_v_c-1;
    signal frame_col_count_s : integer range 0 to frame_resolution_h_c-1;
    
    -- Colours
    constant colour_blue_c  : std_logic_vector(pixel_width_c-1 downto 0) := x"FF" & x"00" & x"00";
    constant colour_red_c   : std_logic_vector(pixel_width_c-1 downto 0) := x"00" & x"FF" & x"00";
    constant colour_green_c : std_logic_vector(pixel_width_c-1 downto 0) := x"00" & x"00" & x"FF";
    constant colour_grey1_c : std_logic_vector(pixel_width_c-1 downto 0) := x"40" & x"40" & x"40";
    constant colour_black_c : std_logic_vector(pixel_width_c-1 downto 0) := x"00" & x"00" & x"00";
    constant colour_white_c : std_logic_vector(pixel_width_c-1 downto 0) := x"FF" & x"FF" & x"FF";
    constant colour_alive_c : std_logic_vector(pixel_width_c-1 downto 0) := colour_white_c;
    constant colour_dead_c  : std_logic_vector(pixel_width_c-1 downto 0) := colour_grey1_c;

    -- Misc
    signal data_all_reg_s : std_logic_vector(board_rows_c*board_cols_c-1 downto 0);
    signal cell_state_current_s : std_logic; -- alive or dead
    signal pixel_current_s : std_logic_vector(pixel_width_c-1 downto 0);
    signal sof_s : std_logic;
    signal eol_s : std_logic;
    signal eof_s : std_logic;
    signal m_axis_consumed : std_logic;

begin

    -- Main FSM
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if    rst_i = '1'                                                             then state_s <= st_reset;
            else
                case state_s is 
                    when st_reset          =>                                                  state_s <= st_wait_for_start;
                    when st_wait_for_start => if (start_i = '1'                         ) then state_s <= st_forward; end if;
                    when st_forward        => if (eof_s = '1' and m_axis_consumed = '1' ) then state_s <= st_wait_for_start; end if;
                    when others            =>                                                  state_s <= st_reset;
                end case;
            end if;
        end if;
    end process;

    -- Handle frame columns
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if    (rst_i = '1'                          ) then frame_col_count_s <= 0;
            elsif (m_axis_consumed = '1' and eol_s = '1') then frame_col_count_s <= 0; 
            elsif (m_axis_consumed = '1'                ) then frame_col_count_s <= frame_col_count_s + 1;
            end if;
        end if;
    end process;

    -- Handle frame rows
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if    (rst_i = '1'                          ) then frame_row_count_s <= 0;
            elsif (m_axis_consumed = '1' and eof_s = '1') then frame_row_count_s <= 0; 
            elsif (m_axis_consumed = '1' and eol_s = '1') then frame_row_count_s <= frame_row_count_s + 1;
            end if;
        end if;
    end process;

    -- Frame and line flags
    eol_s <= '1' when frame_col_count_s >= frame_resolution_h_c-1 else '0';
    eof_s <= '1' when (frame_row_count_s >= frame_resolution_v_c-1 and eol_s = '1') else '0';
    sof_s <= '1' when (frame_row_count_s = 0 and frame_col_count_s = 0) else '0';

    -- Handle board columns/rows
    board_row_count_s <= frame_row_count_s / ratio_expansion_c;
    board_col_count_s <= frame_col_count_s / ratio_expansion_c;

    -- Register incoming data
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if    (rst_i = '1'                ) then data_all_reg_s <= (others => '0');
            elsif (state_s = st_wait_for_start) then data_all_reg_s <= data_all_i; 
            end if;
        end if;
    end process;

    -- cell_state_current_s takes its value from data_all_reg_s[board_row_count*ratio_expansion_c, board_col_count*ratio_expansion_c]
    cell_state_current_s <= data_all_reg_s(board_row_count_s*board_cols_c + board_col_count_s);
    -- pixel_current_s is set to a specific colour according to cell state
    pixel_current_s <= colour_alive_c when (cell_state_current_s = '1') else colour_dead_c;

    -- Master AXIS
    m_axis_consumed <= '1' when (m_axis_tready = '1' and m_axis_tvalid = '1') else '0';
    m_axis_tvalid <= '1' when (state_s = st_forward) else '0';
    m_axis_tdata <= pixel_current_s;
    m_axis_tlast <= eol_s;
    m_axis_tuser <= '1' when (sof_s = '1') else '0';

    done_o <= '1' when (state_s = st_wait_for_start) else '0';

end architecture;