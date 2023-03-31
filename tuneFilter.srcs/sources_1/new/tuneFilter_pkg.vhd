-- vsg_off
library IEEE;
use IEEE.STD_LOGIC_1164.all;
USE ieee.numeric_std.ALL;
use IEEE.math_real.all;

package tuneFilter_pkg is
--constants
constant c_data_w : integer := 16; --data width
constant c_f_order : integer := 8; --filter order
constant c_s_order : integer := 2; --section order
constant c_len_data_frac : integer := 13; --coefficient fractional part length
constant c_len_coeff_frac : integer := 13; --coefficient fractional part length
constant c_len_acc_frac : integer := 28; --accummulator fractional part length
constant c_len_mul_frac : integer := 26; --accummulator fractional part length
constant c_acc_w : integer := c_data_w*2+2; --accummulator width, default = 34
constant c_mul_w : integer := c_data_w*2; --multiplier width, default = 32
constant c_len_cnt_coeff : integer := integer(ceil(log2(real(2*c_s_order+1)))); --number of coefficients for a section, for SOS -> 2*3 = 6 (a1 omitted = 1)
constant c_len_cnt_sample : integer := integer(ceil(log2(real(c_S_Order+1))));
constant c_len_cnt_section : integer := integer(ceil(log2(real(c_f_order/c_s_order))));
constant c_len_sample_mem : integer := c_F_Order/c_s_order*(c_S_Order+1); --sample memory size
constant c_len_coeff_mem : integer := c_F_Order/c_s_order*(2*c_S_Order+1); --coefficient memory size

--types
type t_sample_mem is array (0 to c_len_sample_mem-1) of signed (c_data_w-1 downto 0); --sram
type t_coeff_mem is array (0 to c_len_coeff_mem-1) of signed (c_data_w-1 downto 0); --coefficient memory

--functions
function signed_fixPoint_resize (
    arg               : signed;
    new_size          : integer;
    frac_length       : integer;
    new_frac_length   : integer
    ) return signed;
end package tuneFilter_pkg;

package body tuneFilter_pkg is

    --resizes the coefficient to match accummulator size, preserves bit weight of fixed point numbers
    function signed_fixPoint_resize (
        arg               : signed;
        new_size          : integer;
        frac_length       : integer;
        new_frac_length   : integer
    ) return signed is
        variable left_pad           : signed(new_size-new_frac_length-(arg'length-frac_length)-1 downto 0) := (others => '0');
        variable right_pad          : signed(new_frac_length-frac_length-1 downto 0) := (others => '0');
        variable new_MSB, new_LSB   : integer := 0;
    begin --check if positive or negative and assign correct values to pad variables
        if new_size >= arg'length then --is new_size greater than arg?
            --yes, calculate padding
            if arg(arg'high) = '0' then --arg is positive, pad with zeros
                left_pad := (others => '0');
                right_pad := (others => '0');
            else --arg is negative, pad with ones
                left_pad := (others => '1');
                right_pad := (others => '1');
            end if;
            return left_pad&arg&right_pad;
        else --no, slice arg to new size while preserving bit weight
            new_MSB := arg'length - (arg'length - frac_length - (new_size - new_frac_length));
            new_LSB := frac_length - new_frac_length;
            if arg(arg'high) = '0' then
                return '0'&arg(new_MSB downto new_LSB);
            else
                return '1'&arg(new_MSB downto new_LSB);
            end if;
        end if;
    end;


end package body tuneFilter_pkg;
