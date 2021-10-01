"""
This module export data generator to generate different data patterns for testing.
"""

import random
import os
class DataGen:
    # ----------------------------------------------------#
    # Bytearray Data Generation 
    # ----------------------------------------------------#
    @classmethod
    def array_fullzeros(cls, size: int):
        """Handy alias for full 0s constant array"""
        return bytearray(size)

    @classmethod
    def array_fullff(cls, size: int):
        """Generate an array full of FF"""
        data = bytearray([255])
        for _ in range(1, size):
            data.append(255)
        return data

    @classmethod
    def array_constant(cls, size: int, value: int):
        """Generate an array full of A constant"""
        data = bytearray([value])
        for _ in range(1, size):  # Append the left (size-1) values
            data.append(value)
        return data
    
    @classmethod
    def array_random(cls, size: int):
        """Generate an array full of random value"""
        data = bytearray([random.randint(0,0xFF)])
        for _ in range(1, size):
            data.append(random.randint(0,0xFF))
        return data
    # ----------------------------------------------------#    
    @classmethod
    def array_plus_f(cls, array_in: bytearray):
        """Put another F on the input activations, only support 64 times of operation
        Args:
            array_in (bytearray): activation bytearray
        Returns:
            bytearray: modified activation array
        """
        array_value = int.from_bytes(array_in, byteorder='big')
        array_value = array_value*16 + 15
        array_mask = int(2**256 -1)   # Array mask to avoid data longer than 32 bytes
        array_value = array_value & array_mask
        array_out = array_value.to_bytes(32, byteorder='big')
        array_out = bytearray(array_out)
        return array_out

    @classmethod
    def array_plusone_each(cls, array_in: bytearray):
        """Increment a 1 in each input activation
        Args:
            array_in (bytearray): activation bytearray
        Returns:
            bytearray: modified activation array
        """
        for i in range(len(array_in)):
            if array_in[i]  < 255: # Avoid error when byte data >255
                array_in[i]+=17
        return array_in
    
    # @classmethod
    # def array_shift_l_loop(array_in: bytearray):
    #     """Shift left the array by 8 bit in a loop style"""
    #     last_byte = array_in[0]
    #     array_in.pop(0)
    #     array_in.append(last_byte)
    
    @classmethod    
    def array_shift_l4bit(array_in: bytearray):
        """Shift left the array by 4-bit, only support 64 times of operation"""
        array_value = int.from_bytes(array_in, byteorder='big')
        array_value = array_value << 4
        array_out = array_value.to_bytes(32, byteorder='big')
        return array_out
    
    @classmethod
    def array_plus_one(array_in: bytearray):
        """Plus 1 on the 64th input activation"""
        array_value = int.from_bytes(array_in, byteorder='big')
        array_value = array_value + 1
        array_mask  = int(2**256 -1)   # Array mask to avoid data longer than 32 bytes
        array_value = array_value & array_mask
        array_out = array_value.to_bytes(32, byteorder='big')
        array_out = bytearray(array_out)
        return array_out
    # ----------------------------------------------------#
    # Data Pattern transmitted to FIFO
    # ----------------------------------------------------#
    @classmethod
    def write_byte(cls, addr:int, data:int):
        """
        Generate proper 32-bit data pattern for Writing 1 byte data into itf_reg
        Sequence of the 32-bit data pipe in FIFOA:
        [7:0] [15:8] [23:16] [31:24]
        """
        assert 0 < addr <= 6 and 0 <= data <= 255, "Invalid size provided."
        w_four_byte = [data, addr, 1, 0] # data + addr + 1 (means write) + (arbitary value)
        return bytearray(w_four_byte)

    @classmethod
    def read_byte(cls, addr:int):
        """
        Generate proper 32-bit data pattern for Reading 1 byte data into itf_reg
        Sequence of the 32-bit data pipe in FIFOA:
        [7:0] [15:8] [23:16] [31:24]
        """
        assert 0 < addr <= 6 , "Invalid addr provided."
        r_four_byte = [0, addr, 0, 0] #(arbitary value) + addr + 0 (means read) + (arbitary value)
        return bytearray(r_four_byte)

    @classmethod
    def indir_write(cls, ind_addr:int, ind_data:int):
        """
        With a 1byte address and a 2byte data, generate
        proper data pattern for indirect writing process
        data pattern: 4x32 bit
        """
        send_waddr = cls.write_byte(0x02, ind_addr)          # Send Address of inner reg
        send_data = ind_data.to_bytes(2,"big")
        send_data_lsb = cls.write_byte(0x03, send_data[1])   # Send lsb of data
        send_data_msb = cls.write_byte(0x04, send_data[0])   # Send msb of data      
        send_w_oper = cls.write_byte(0x01, 0x03)             # Operation: Writing
        send_waddr.extend(send_data_lsb)
        send_waddr.extend(send_data_msb)
        send_waddr.extend(send_w_oper)
        return send_waddr
    
    @classmethod
    def indir_read(cls, ind_addr:int):
        """
        With a 1byte address, generate proper data 
        pattern for indirect reading process
        data pattern: 4x32 bit
        """
        send_raddr  = cls.write_byte(0x02, ind_addr)        # Send Address of inner reg
        send_r_oper = cls.write_byte(0x01, 0x02)            # Operation: Reading
        send_rmsb   = cls.read_byte(0x06)                   # Read 1 byte MSB data in itf_reg 0x06
        send_rlsb   = cls.read_byte(0x05)                   # Read 1 byte LSB data in itf_reg 0x05
        send_raddr.extend(send_r_oper)
        send_raddr.extend(send_rmsb)
        send_raddr.extend(send_rlsb)
        return send_raddr

    # ----------------------------------------------------#
    # Test Pattern
    # ----------------------------------------------------#
    @classmethod
    def test_write(cls):
        """"Write data into register 02, 03, 04: 0XBB, 0XCC, 0XDD"""
        to_be_send =[0xAA,0x02,0x01,0x00,  0xBB,0x02,0x01,0x00,  0xCC,0x03,0x01,0x00 , 0xDD,0x04,0x01,0x00]
        out_16byte=bytearray(to_be_send)
        return out_16byte

    @classmethod
    def test_read(cls):
        """"Read data from register 02, 03, 04, 05"""
        to_be_send =[0x00,0x02,0x00,0x00,  0x00,0x03,0x00,0x00,  0x00,0x04,0x00,0x00 , 0x00,0x05,0x00,0x00]
        out_16byte=bytearray(to_be_send)
        return out_16byte
    # ----------------------------------------------------# 

        
