----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
--! board_init.vhd
--! 
--! Generates an initial distribution for the array. Allows moving a cursor in the
--! board and toggle the state for each of the cells.

----------------------------------------------------------------------------------
----------------------------------------------------------------------------------

----------------------------------------------------------------------------------
-- Internal package
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package board_init_pkg is
    type board_init_cmd_t is (nop, cursor_move_U, cursor_move_D, cursor_move_L, cursor_move_R, toggle_cell);
end package;

----------------------------------------------------------------------------------
-- Libraries
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.utils_pkg.all;
use work.board_init_pkg.all;
use work.cells_pkg.all;

----------------------------------------------------------------------------------
-- Entity
----------------------------------------------------------------------------------

entity board_init is
    generic (
        one_s_max_c : positive := 16
    ); port (
        clk_i        : in  std_logic;
        rst_i        : in  std_logic;
        cmd_i        : in  board_init_cmd_t;
        board_arr_o  : out cell_array_t;
        blinky_arr_o : out cell_array_t;
        count_i      : in  unsigned(log2_ceil(one_s_max_c)-1 downto 0)
    );
end entity;

----------------------------------------------------------------------------------
-- Architecture
----------------------------------------------------------------------------------

architecture behavioural of board_init is

    type cursor_t is record
        pos_col : integer range 0 to num_cols_c;
        pos_row : integer range 0 to num_rows_c;
    end record;
    signal cursor_s : cursor_t;
    signal board_arr_s : cell_array_t;

begin

    -- Cursor handling
    process (clk_i)
    begin
        if rising_edge(clk_i) then

            if    rst_i = '1'                       then cursor_s.pos_col <= 0; cursor_s.pos_row <= 0; 
            elsif cmd_i = cursor_move_U             then 
                if (cursor_s.pos_row = 0)           then cursor_s.pos_row <= num_rows_c-1; 
                else                                     cursor_s.pos_row <= cursor_s.pos_row - 1;
                end if;
            elsif cmd_i = cursor_move_D             then 
                if cursor_s.pos_row = num_rows_c-1  then cursor_s.pos_row <= 0; 
                else                                     cursor_s.pos_row <= cursor_s.pos_row + 1;
                end if;
            elsif cmd_i = cursor_move_L            then 
                if cursor_s.pos_col = 0            then cursor_s.pos_col <= num_cols_c-1; 
                else                                    cursor_s.pos_col <= cursor_s.pos_col - 1;
                end if;
            elsif cmd_i = cursor_move_R            then 
                if cursor_s.pos_col = num_cols_c-1 then cursor_s.pos_col <= 0;
                else                                    cursor_s.pos_col <= cursor_s.pos_col + 1;
                end if;                                    
            end if;           
            
        end if;
    end process;

    -- board array
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if    rst_i = '1'         then cells_array_set (board_arr_s, '0');
            elsif cmd_i = toggle_cell then board_arr_s(cursor_s.pos_row, cursor_s.pos_col).state <= not board_arr_s(cursor_s.pos_row, cursor_s.pos_col).state;
            end if;
        end if;
    end process;

    -- Output board array
    board_arr_o <= board_arr_s;

    -- Blinky output: all cells unmodified but that one pointed by cursor, which will be driven by the counter msb
    process (all)
    begin
        blinky_arr_o <= board_arr_s;
        if (count_i < one_s_max_c/2) then blinky_arr_o(cursor_s.pos_row, cursor_s.pos_col).state <= '0';
        else                              blinky_arr_o(cursor_s.pos_row, cursor_s.pos_col).state <= '1';
        end if;
    end process;    

end architecture;
