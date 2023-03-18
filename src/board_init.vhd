----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
--! board_init.vhd
--! 
--! Generates an initial distribution for the array. Allows moving a cursor in the
--! board and toggle the state for each of the cells

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
        posX : integer range 0 to num_rows_c;
        posY : integer range 0 to num_cols_c;
    end record;
    signal cursor_s : cursor_t;
    signal board_arr_s : cell_array_t;

begin

    -- Cursor handling
    process (clk_i)
    begin
        if rising_edge(clk_i) then

            if    rst_i = '1'                   then cursor_s.posX <= 0; cursor_s.posY <= 0; 
            elsif cmd_i = cursor_move_U         then 
                if (cursor_s.posY = 0)          then cursor_s.posY <= num_rows_c-1; 
                else                                 cursor_s.posY <= cursor_s.posY - 1;
                end if;
            elsif cmd_i = cursor_move_D         then 
                if cursor_s.posY = num_rows_c-1 then cursor_s.posY <= 0; 
                else                                 cursor_s.posY <= cursor_s.posY + 1;
                end if;
            elsif cmd_i = cursor_move_L         then 
                if cursor_s.posX = 0            then cursor_s.posX <= num_cols_c-1; 
                else                                 cursor_s.posX <= cursor_s.posX - 1;
                end if;
            elsif cmd_i = cursor_move_R         then 
                if cursor_s.posX = num_cols_c-1 then cursor_s.posX <= 0;
                else                                 cursor_s.posX <= cursor_s.posX + 1;
                end if;                                    
            end if;           
            
        end if;
    end process;

    -- board array
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if    rst_i = '1'         then cells_array_set (board_arr_s, '1');
            elsif cmd_i = toggle_cell then board_arr_s(cursor_s.posX, cursor_s.posY).state <= not board_arr_s(cursor_s.posX, cursor_s.posY).state;
            end if;
        end if;
    end process;

    -- Output board array
    board_arr_o <= board_arr_s;

    -- Blinky output: all cells unmodified but that one pointed by cursor, which will be driven by the counter msb
    process (all)
    begin
        blinky_arr_o <= board_arr_s;
        blinky_arr_o(cursor_s.posX, cursor_s.posY).state <= count_i(log2_ceil(one_s_max_c)-1);
    end process;    

end architecture;
