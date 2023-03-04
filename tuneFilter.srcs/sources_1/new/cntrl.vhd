----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 02/10/2023 10:02:35 AM
-- Design Name: 
-- Module Name: control - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.tuneFilter_pkg.all;
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity control is
    Port ( clk, rst, RQ : in STD_LOGIC;
           GNT, RDY, en : out STD_LOGIC);
end control;

architecture Behavioral of control is
--types----------------------------------------------------------------------------
type t_state is (idle, write, read);
--signals--------------------------------------------------------------------------
signal sample_mem : t_sample_mem := (others => (others => '0')); --sample memory
signal coeff_mem : t_coeff_mem := (
    "0000001011111101", "1000101111100001", "0011101000011001", "0100000000000000", "0111111111111111", "0100000000000000",
    others => (others => '0')); --coefficient memory in order: s1, a2, a3, b1, b2, b3
signal wdata_sample, wdata_coeff, rdata_sample, rdata_coeff : signed(c_data_w-1 downto 0) := (others => '0'); --read and write signals
signal waddr_sample, raddr_sample : unsigned(c_len_sample_mem-1 downto 0);
signal waddr_coeff, raddr_coeff : unsigned(c_len_coeff_mem-1 downto 0);
signal we_sample_mem, we_coeff_mem : std_logic;
signal new_delay, result : signed(c_data_w-1 downto 0);
signal state, next_state : t_state := idle;
-----------------------------------------------------------------------------------
begin
    p_main: process (clk, rst)
        begin
            if rst = '1' then
                new_delay <= (others => '0');
                result <= (others => '0');
                state <= idle;
            elsif rising_edge(clk) then
            
            end if;
        end process;

    p_fsm: process (state)
        begin

            case (state) is
                when idle =>

                when write =>

                when  read =>
                
            end case;
        end process;

    p_sample_memory: process (clk, rst, we_sample_mem, wdata_sample, waddr_sample)
        --sample_mem write
        begin
            if rst = '1' then
                sample_mem <= (others => (others => '0'));
            elsif rising_edge(clk) then
                if we_sample_mem = '1' then
                    sample_mem(to_integer(waddr_sample)) <= wdata_sample; --write
                end if;
            end if;
        end process;
        --sample memory read
        rdata_sample <= sample_mem(to_integer(raddr_sample)); --read

    p_coeff_memory: process (clk, we_coeff_mem, wdata_coeff, waddr_coeff)
        --coefficient memory write
        begin
            if rst = '1' then
                coeff_mem <= (others => (others => '0'));
            elsif rising_edge(clk) then
                if we_coeff_mem = '1' then
                    coeff_mem(to_integer(waddr_coeff)) <= wdata_coeff; --write
                end if;
            end if;
        end process;
        --coefficient memory read
        rdata_coeff <= coeff_mem(to_integer(raddr_coeff)); --read

end Behavioral;
