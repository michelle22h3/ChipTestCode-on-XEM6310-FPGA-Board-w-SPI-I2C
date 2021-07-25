"""
This module export data generator to generate different data patterns for testing.
"""

import random


class DataGen:

    @classmethod
    def constant_array(cls, size: int, constant: int) -> bytearray:
        """
        Helper to generate the data array with the specified constant value.
        :param size: number of bytes in the result.
        :param constant: the specified value of constant value.
        :return: the generate data byte array.
        """
        assert size > 0 and 0 <= constant < 256, "Invalid size or constant size provided."
        return bytearray([constant] * size)

    @classmethod
    def full_zeros(cls, size: int) -> bytearray:
        """Handy alias for full 0s constant array."""
        return cls.constant_array(size, 0)

    @classmethod
    def full_ones(cls, size):
        """Handy alias for full 1s constant array."""
        return cls.constant_array(size, 1)

    @classmethod
    def list_2_bytearray(cls, data: list) -> bytearray:
        """Helper to generate the byte array from the specified data."""
        return bytearray(data)

    @classmethod
    def random_array(cls, size: int) -> bytearray:
        """
        Helper to generate the data array with the random number in the array.
        :param size: number of bytes in the result.
        :return: the generate data byte array.
        """
        assert size > 0, "Invalid size provided."
        random_list = [random.randint(0, 255) for _ in range(size)]
        return bytearray(random_list)

    @classmethod
    def image_2_bytearray(cls, image_file: str) -> bytearray:
        """
        Helper to generate the data bytearray with the given image file.
        :param image_file: file path of the image to be converted.
        :return: the data bytearray of the image.
        """
        raise NotImplementedError("TODO...")

    @classmethod
    def gen_mem_init(cls, data: bytearray, mem_init_file: str):
        """
        Helper to generate the verilog memory initial file for the specified data.
        :param data: the specified bytearray data to be generated.
        :param mem_init_file: file name for memory initialization.
        """
        assert type(data) == bytearray, "Unexpected type for the specified data."
        with open(mem_init_file, "w") as fp:
            for num in data:
                fp.write("{:02x} // {}\n".format(num, num))  # Write data in hex with decimal as comment
