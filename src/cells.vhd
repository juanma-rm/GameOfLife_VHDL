----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
--! cells.vhd
--! 
--! Stores the array of cells and update each cell state when requested

----------------------------------------------------------------------------------
----------------------------------------------------------------------------------

----------------------------------------------------------------------------------
-- Internal package
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.utils_pkg.all;

package cells_pkg is

    type cell_t is record
        state   : std_logic;
    end record;
    type cell_array_t is array (0 to num_rows_c, 0 to num_cols_c) of cell_t;
    function cells_array_init (constant value : in std_logic) return cell_array_t;
    procedure cells_array_set (signal cells_arr : inout cell_array_t; constant value : in std_logic);
    function cells_array_to_slv (constant cells_arr : in cell_array_t) return std_logic_vector;
    type neighbour_pos_t is (top_left, top_center, top_right, left, right, bottom_left, bottom_center, bottom_right);
    function cells_get_neigh_state (constant cells_arr : in cell_array_t; constant row : in natural; constant col : in natural; constant neighbour_pos : in neighbour_pos_t) return integer;
    function cells_next_gen (constant cells_arr : in cell_array_t; constant row : in natural; constant col : in natural) return std_logic;

end package;

package body cells_pkg is

    function cells_array_init (constant value : in std_logic) return cell_array_t is
        variable cells_arr : cell_array_t;
    begin
        for row in 0 to num_rows_c-1 loop
            for col in 0 to num_cols_c-1 loop
                cells_arr(row,col).state := value;
            end loop;
        end loop;
        return cells_arr;
    end function;

    procedure cells_array_set (signal cells_arr : inout cell_array_t; constant value : in std_logic) is
    begin
        for row in 0 to num_rows_c-1 loop
            for col in 0 to num_cols_c-1 loop
                cells_arr(row,col).state <= value;
            end loop;
        end loop;
    end procedure;    

    function cells_array_to_slv (constant cells_arr : in cell_array_t) return std_logic_vector is
        variable slv : std_logic_vector(num_rows_c*num_cols_c - 1 downto 0);
    begin
        for row in 0 to num_rows_c-1 loop
            for col in 0 to num_cols_c-1 loop
                slv(row*num_cols_c + col) := cells_arr(row,col).state;
            end loop;
        end loop;
        return slv;
    end function;

    function cells_get_neigh_state (constant cells_arr : in cell_array_t; constant row : in natural; constant col : in natural; constant neighbour_pos : in neighbour_pos_t) return integer is
        variable neighbour : cell_t;
        variable state     : integer;
    begin
        if      (neighbour_pos = top_left     ) then neighbour := cells_arr(row-1,col-1);
        elsif   (neighbour_pos = top_center   ) then neighbour := cells_arr(row-1,col  );
        elsif   (neighbour_pos = top_right    ) then neighbour := cells_arr(row-1,col+1);
        elsif   (neighbour_pos = left         ) then neighbour := cells_arr(row  ,col-1);
        elsif   (neighbour_pos = right        ) then neighbour := cells_arr(row  ,col+1);
        elsif   (neighbour_pos = bottom_left  ) then neighbour := cells_arr(row+1,col-1);
        elsif   (neighbour_pos = bottom_center) then neighbour := cells_arr(row+1,col  );
        elsif   (neighbour_pos = bottom_right ) then neighbour := cells_arr(row+1,col+1);
        end if;
        if (neighbour.state = '1') then state := 1; else state := 0; end if;
        return state;
    end function;

    function cells_next_gen (constant cells_arr : in cell_array_t; constant row : in natural; constant col : in natural) return std_logic is
        variable state_next_gen  : std_logic := '0'; -- We suppose cell will be dead
        variable num_neigh_alive : integer := 0;
    begin
        -- Count alive cells in neighbourhood
        -- Top left corner
        if (row = 0 and col = 0) then
            -- num_neigh_alive := unsigned(cells_arr(row,col+1).state) + unsigned(cells_arr(row+1,col).state) + unsigned(cells_arr(row+1,col+1).state);
            num_neigh_alive := cells_get_neigh_state(cells_arr, row, col, right) + cells_get_neigh_state(cells_arr, row, col, bottom_center) + cells_get_neigh_state(cells_arr, row, col, bottom_right);
        -- Top right corner
        elsif (row = 0 and col = num_cols_c-1) then 
            -- num_neigh_alive := unsigned(cells_arr(row,col-1).state) + unsigned(cells_arr(row+1,col-1).state) + unsigned(cells_arr(row+1,col).state);
            num_neigh_alive := cells_get_neigh_state(cells_arr, row, col, left) + cells_get_neigh_state(cells_arr, row, col, bottom_center) + cells_get_neigh_state(cells_arr, row, col, bottom_left);
        -- Top (no corner)
        elsif (row = 0) then
            -- num_neigh_alive := unsigned(cells_arr(row,col-1).state) + unsigned(cells_arr(row,col+1).state) + unsigned(cells_arr(row+1,col-1).state) + unsigned(cells_arr(row+1,col).state) + unsigned(cells_arr(row+1,col+1).state);
            num_neigh_alive := cells_get_neigh_state(cells_arr, row, col, left) + cells_get_neigh_state(cells_arr, row, col, right) + cells_get_neigh_state(cells_arr, row, col, bottom_left) + cells_get_neigh_state(cells_arr, row, col, bottom_center) + cells_get_neigh_state(cells_arr, row, col, bottom_right);
        -- Bottom left corner
        elsif (row = num_rows_c-1 and col = 0) then
            -- num_neigh_alive := unsigned(cells_arr(row-1,col).state) + unsigned(cells_arr(row-1,col+1).state) + unsigned(cells_arr(row,col+1).state);
            num_neigh_alive := cells_get_neigh_state(cells_arr, row, col, right) + cells_get_neigh_state(cells_arr, row, col, top_center) + cells_get_neigh_state(cells_arr, row, col, top_right);
        -- Bottom right corner
        elsif (row = num_rows_c-1 and col = num_cols_c-1) then 
            -- num_neigh_alive := unsigned(cells_arr(row-1,col-1).state) + unsigned(cells_arr(row-1,col).state) + unsigned(cells_arr(row,col-1).state);
            num_neigh_alive := cells_get_neigh_state(cells_arr, row, col, left) + cells_get_neigh_state(cells_arr, row, col, top_center) + cells_get_neigh_state(cells_arr, row, col, top_left);
        -- Bottom (no corner)
        elsif (row = 0) then
            -- num_neigh_alive := unsigned(cells_arr(row,col-1).state) + unsigned(cells_arr(row,col+1).state) + unsigned(cells_arr(row-1,col-1).state) + unsigned(cells_arr(row-1,col).state) + unsigned(cells_arr(row-1,col+1).state);
            num_neigh_alive := cells_get_neigh_state(cells_arr, row, col, left) + cells_get_neigh_state(cells_arr, row, col, right) + cells_get_neigh_state(cells_arr, row, col, top_left) + cells_get_neigh_state(cells_arr, row, col, top_center) + cells_get_neigh_state(cells_arr, row, col, top_right);
        -- Left (no corner)
        elsif (col = 0) then
            -- num_neigh_alive := unsigned(cells_arr(row-1,col).state) + unsigned(cells_arr(row-1,col+1).state) + unsigned(cells_arr(row,col+1).state) + unsigned(cells_arr(row+1,col).state) + unsigned(cells_arr(row+1,col+1).state);
            num_neigh_alive := cells_get_neigh_state(cells_arr, row, col, top_center) + cells_get_neigh_state(cells_arr, row, col, top_right) + cells_get_neigh_state(cells_arr, row, col, right) + cells_get_neigh_state(cells_arr, row, col, bottom_center) + cells_get_neigh_state(cells_arr, row, col, bottom_right);
        -- Right (no corner)
        elsif (col = num_cols_c-1) then
            -- num_neigh_alive := unsigned(cells_arr(row-1,col-1).state) + unsigned(cells_arr(row-1,col).state) + unsigned(cells_arr(row,col-1).state) + unsigned(cells_arr(row+1,col-1).state) + unsigned(cells_arr(row+1,col).state);
            num_neigh_alive := cells_get_neigh_state(cells_arr, row, col, top_center) + cells_get_neigh_state(cells_arr, row, col, top_left) + cells_get_neigh_state(cells_arr, row, col, left) + cells_get_neigh_state(cells_arr, row, col, bottom_center) + cells_get_neigh_state(cells_arr, row, col, bottom_left);
        -- Other (no corner) - 9 neighbours
        else
            -- num_neigh_alive := unsigned(cells_arr(row-1,col-1).state) + unsigned(cells_arr(row-1,col).state) + unsigned(cells_arr(row-1,col+1).state) + unsigned(cells_arr(row,col-1).state) + unsigned(cells_arr(row,col+1).state) + unsigned(cells_arr(row+1,col-1).state) + unsigned(cells_arr(row+1,col).state) + unsigned(cells_arr(row+1,col+1).state);
            num_neigh_alive := cells_get_neigh_state(cells_arr, row, col, top_left) + cells_get_neigh_state(cells_arr, row, col, top_center) + cells_get_neigh_state(cells_arr, row, col, top_right) + cells_get_neigh_state(cells_arr, row, col, left) + cells_get_neigh_state(cells_arr, row, col, right) + cells_get_neigh_state(cells_arr, row, col, bottom_left) + cells_get_neigh_state(cells_arr, row, col, bottom_center) + cells_get_neigh_state(cells_arr, row, col, bottom_right);
        end if;

        -- If any condition for cell alive is met, next state will be alive
        if  ( ( cells_arr(row,col).state = '1' and (num_neigh_alive = 2 or num_neigh_alive = 3 )) or
              ( cells_arr(row,col).state = '0' and num_neigh_alive = 3) )  then
            state_next_gen := '1';
        end if;
        return state_next_gen;
    end function;    

end cells_pkg;

----------------------------------------------------------------------------------
-- Libraries
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.utils_pkg.all;
use work.cells_pkg.all;

----------------------------------------------------------------------------------
-- Entity
----------------------------------------------------------------------------------

entity cells is
    port (
        clk_i         : in  std_logic;
        rst_i         : in  std_logic;
        next_iter_i   : in  std_logic;
        done_o        : out std_logic;
        cells_arr_o   : out std_logic_vector(num_rows_c*num_cols_c - 1 downto 0)
    );
end entity;

----------------------------------------------------------------------------------
-- Architecture
----------------------------------------------------------------------------------

architecture behavioural of cells is

    signal cells_prev_s : cell_array_t := cells_array_init('1');
    signal cells_next_s : cell_array_t := (others => (others => (state => '0')));

    type state_t is (st_init, st_wait, st_calculate, st_update_prev);
    signal state_s      : state_t;

begin
    
    cells_arr_o <= cells_array_to_slv(cells_prev_s);

    -- FSM
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                state_s <= st_init;
            else
                case state_s is
                    when st_init        => state_s <= st_wait;
                    when st_wait        => if (next_iter_i = '1') then state_s <= st_calculate; end if;
                    when st_calculate   => state_s <= st_update_prev;
                    when st_update_prev => state_s <= st_wait;
                    when others         => state_s <= st_init;
                end case;
            end if;
        end if;
    end process;

    done_o <= '1' when (state_s = st_wait) else '0';

    -- Update cells_next with next generation states
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if state_s = st_calculate then
                for row in 0 to num_rows_c-1 loop
                    for col in 0 to num_cols_c-1 loop
                        cells_next_s(row,col).state <= cells_next_gen(cells_prev_s, row, col);
                    end loop;
                end loop;
            end if;
        end if;
    end process;

    -- Update cells_prev once next generation is calculated
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if state_s = st_init then
                cells_array_set (cells_prev_s, '1');
            elsif state_s = st_update_prev then
                for row in 0 to num_rows_c-1 loop
                    for col in 0 to num_cols_c-1 loop
                        cells_prev_s(row, col).state <= cells_next_s(row,col).state;
                    end loop;
                end loop;
            end if;
        end if;
    end process;

end architecture;
