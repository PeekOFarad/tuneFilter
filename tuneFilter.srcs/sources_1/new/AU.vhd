----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 02/10/2023 10:02:35 AM
-- Design Name: 
-- Module Name: AU - Behavioral
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
library work;
use IEEE.STD_LOGIC_1164.ALL;
USE ieee.numeric_std.ALL;
use work.tuneFilter_pkg.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity AU is
    Port ( clk, rst, we_sample_mem, we_coeff_mem : in STD_LOGIC;
           waddr_sample, waddr_coeff : in std_logic_vector(c_F_Order*c_S_Order-1 downto 0);
           data_in : in STD_LOGIC_VECTOR (c_data_w-1 downto 0);
           sample_out : out std_logic_vector(c_data_w downto 0);
           data_out : out STD_LOGIC_VECTOR (c_data_w-1 downto 0));
end AU;

architecture Behavioral of AU is
--signals--------------------------------------------------------------------------
signal sample_mem : t_mem_arr := (others => (others => '0')); --sample memory
signal wdata_sample, wdata_coeff : signed(c_data_w-1 downto 0) := (others => '0');
signal coeff_mem : t_coeff_mem := (
    "0000001011111101", "0100000000000000", "0111111111111111", "0100000000000000", "1000101111100001", "0011101000011001",
    others => (others => '0')
); --coefficient memory in order: s1, b1, b2, b3, a2, a3
signal coeff_mem_address : unsigned(c_len_coeff_address-1 downto 0);
signal cnt_mul_mux : unsigned;
signal mul, mul_c, mul_s : signed(c_mul_w-1 downto 0); --2*c_data_w product
signal acc_c, acc_s : signed(c_acc_w-1 downto 0); --2*c_data_w+2 accumulator size
signal acc : signed(c_acc_w downto 0);
-----------------------------------------------------------------------------------
begin

p_reg : process (clk, rst)
begin
    if rst = '1' then
    --reset states
    elsif rising_edge(clk) then
    --registers
    if 1 = 1 then
        data_out <= std_logic_vector(acc); --outgoing data
        mul_s <= mul_c; --product
        acc_s <= acc_c; --accumulator
    end if;
    end if;      
end process;

--Multiplication of samples and coefficients
p_mul: process (cnt_mul_mux)
begin
    case cnt_mul_mux is
        --scale
        when to_unsigned(0,1) => mul <= signed(data_in)*shift_left(coeff_mem(to_integer(unsigned(waddr_coeff))),2); --TODO input data is s16,15 and coefficents are s16,13
        --coefficents
        when to_unsigned(1,1) => mul <= sample_mem(to_integer(unsigned(waddr_sample)))*coeff_mem(to_integer(unsigned(waddr_coeff)));
        --TODO -> in this instance write accumulated result into sram     
        when others =>
            null;
    end case;
end process;
--think about adding a pipeline p_mul_overflow <= p_mul (decrease critical path)

--Check for product overflow
p_mul_overflow: process (mul) 
begin
    if mul(c_data_w*4-1) = '0' then -- positive number
	    if mul((c_data_w*4-1) downto (c_data_w*4-c_data_w-1)) > 0 then --overflow?
			mul_c <= '0'&(c_data_w*2-2 downto 0 => '1'); --yes, saturate to +max
		else
			mul_c <= mul((c_data_w*4-c_data_w-1) downto c_data_w); --no, leave as is 
		end if;
    else  --negative number
		if mul((c_data_w*4-1) downto (c_data_w*4-c_data_w-1)) < -1 then --overflow?
			mul_c <= '1'&(c_data_w*2-2 downto 0 => '0'); --yes, saturate down
		else
			mul_c <= mul((c_data_w*4-c_data_w-1) downto c_data_w); --no, leave as is
		end if;
     end if;
        
end process;

p_add:
    acc <= resize(acc_s, c_acc_w+1) + signed_fixpoint_resize(mul_s, c_acc_w+1, c_len_acc_frac, c_len_acc_frac); 
--think about adding a pipeline p_acc_overflow <= p_acc (decrease critical path)

--Check for sum overflow
p_add_overflow: process (acc)
begin
    acc_c <= (others => '0');
    if acc(c_acc_w) = acc(c_acc_w-1) then --no overflow
		acc_c <= resize(acc, c_acc_w);
    elsif acc(c_acc_w) > acc(c_acc_w-1) then --overflow
		acc_c <= '1'&(c_acc_w-2 downto 0 => '0'); --negative overflow
	else
		acc_c <= '0'&(c_acc_w-2 downto 0 => '1'); --positive overflow
    end if;       
end process;   

--TODO -> this sram code's kinda fucked, gotta figure it out properly; chance of it being correct ~= 1:(answer to life the universe and everything)
p_sampleMemory: process (clk, we_sample_mem)
begin
    if rising_edge(clk) then
        if we_sample_mem = '1' then
            --sample_mem(to_integer(cnt_section*2+1)) <= sample_mem(to_integer(cnt_section*2)); 
            sample_mem(to_integer(unsigned(waddr_sample))) <= wdata_sample;-- TODO -> assign feedback result (data_in*s1+sample_mem(1)*a2+sample_mem*a3) to data_sample; 
        end if;
    end if;
end process;

p_cff_mem: process (clk, we_coeff_mem)
begin
    if rising_edge(clk) then
        if we_coeff_mem = '1' then
            coeff_mem(to_integer(unsigned(waddr_coeff))) <= wdata_coeff; --load in filter coefficients (except a1? -> it's always 1)
        end if;
    end if;
end process;

end Behavioral;
