import sys
import argparse
import numpy as np
import matplotlib.pyplot as plt
from tqdm import tqdm
np.set_printoptions(threshold=sys.maxsize)

def parse_polynomial(poly_str):
    """Parses the polynomial string to extract coefficients."""
    poly_str = poly_str.replace('Primitive(', '').replace(') mod 2 ;', '').strip()
    terms = poly_str.split('+')
    max_power = max(int(term.split('^')[-1]) if '^' in term else 0 for term in terms)
    coeffs = [0] * (max_power + 1)
    for term in terms:
        if 'X^' in term:
            power = int(term.split('^')[-1])
            coeffs[max_power - power] = 1
        elif 'X' in term:
            coeffs[max_power - 1] = 1
        else:
            coeffs[-1] = int(term)
    return coeffs

def read_polynomial(file_path, line_number):
    """Reads a specific line from a polynomial file."""
    try:
        with open(file_path, 'r') as file:
            for i, line in enumerate(file, start=1):
                if i == line_number:
                    return parse_polynomial(line)
            raise ValueError(f"Entry number {line_number} exceeds the number of lines in the file.")
    except FileNotFoundError:
        raise FileNotFoundError(f"The specified file does not exist: {file_path}")

def build_state_transition_matrix(coeffs):
    """Builds the state transition matrix from LFSR coefficients."""
    n = len(coeffs) - 1
    matrix = np.zeros((n, n), dtype=int)
    matrix[:-1, 1:] = np.eye(n - 1, dtype=int)  # Shift part
    matrix[-1, :] = coeffs[:-1]  # Feedback part from the polynomial coefficients
    return matrix

def setup():
    """Setup function to initialize and parse command line arguments, and build matrix."""
    parser = argparse.ArgumentParser(description="Process LFSR polynomials.")
    parser.add_argument("degree", type=int, nargs='?', default=10, choices=range(10, 65),
                        help="Degree of the polynomial (range 10-64). Default is 10.")
    parser.add_argument("entry", type=int, nargs='?', default=1,
                        help="Entry in the file (1-indexed). Default is 1.")
    parser.add_argument("cs", type=int, nargs='?', default=None,
                        help="Channel separation (integer). Defaults to 2*degree.")
    parser.add_argument("nc", type=int, nargs='?', default=None,
                        help="Number of channels (integer). Defaults to 2*degree.")
    parser.add_argument("method", type=str, choices=['consecutive', 'separated'], default='consecutive',
                        help="Method for selecting channels: 'consecutive' or 'separated'. Default is 'consecutive'.")
    parser.add_argument("num_integers", type=int, default=8,
                        help="Number of 8-bit integers to generate. Default is 8.")
    parser.add_argument("bit_width", type=int, default=8,
                        help="Bit width of each integer. Default is 8.")
    parser.add_argument("cycles", type=int, default=100,
                        help="Number of cycles to simulate. Default is 100.")
    parser.add_argument("experiments", type=int, default=10,
                        help="Number of experiments to perform. Default is 10.")
    args = parser.parse_args()

    if args.cs is None:
        args.cs = 2 * args.degree
    if args.nc is None:
        args.nc = 2 * args.degree

    file_path = f"polynomials/{args.degree}.txt"
    coefficients = read_polynomial(file_path, args.entry)
    tm = build_state_transition_matrix(coefficients)

    # Validate NC * CS < 2^Degree
    if args.nc * args.cs >= 2 ** args.degree:
        raise ValueError("NC x CS must be smaller than 2^Degree.")

    ps = build_phase_shifter_matrix(tm, args.nc, args.cs)

    return args.degree, args.nc, args.cs, tm, ps, args.method, args.num_integers, args.bit_width, args.cycles, args.experiments

def build_phase_shifter_matrix(tm, nc, cs):
    """Builds the phase shifter matrix."""
    d = tm.shape[0]
    ps = np.zeros((nc, d), dtype=int)
    for i in range(1, nc):
        raised_matrix = matrix_power_gf2(tm, cs * i)
        ps[i, :] = raised_matrix[-1]
    return ps

def matrix_power_gf2(matrix, k):
    """Raise a matrix to the power k in GF(2)."""
    result = np.eye(matrix.shape[0], dtype=int)
    power = matrix.copy()
    while k:
        if k % 2 == 1:
            result = np.dot(result, power) % 2
        power = np.dot(power, power) % 2
        k //= 2
    return result

def bits_to_signed_integer(bits):
    """Convert a list of bits to a signed integer using two's complement."""
    bit_string = ''.join(map(str, bits))
    value = int(bit_string, 2)
    if bits[0] == 1:  # Check the sign bit
        value -= 2**len(bits)
    return value

def simulate_lfsr_phase_shifter(tm, ps, initial_state, cycles, method, num_integers, bit_width):
    current_state = initial_state
    lfsr_states = [current_state]
    ps_outints = []

    for _ in range(cycles):
        # Update the LFSR state
        current_state = np.dot(tm, current_state) % 2
        lfsr_states.append(current_state.copy())

        # Gather bits for the integers
        integers = []
        for i in range(num_integers):
            bits = []
            for j in range(bit_width):
                channel_index = (i * bit_width + j) if method == 'consecutive' else (i + j * num_integers)
                bits.append(np.dot(ps[channel_index], current_state) % 2)
            # Convert bits to signed integer
            integer = bits_to_signed_integer(bits)
            integers.append(integer)
        ps_outints.append(integers)

    return ps_outints

def analyze_and_plot_histogram(all_experiment_data, cs, experiments):
    """Analyze outputs, plot a histogram, and save the figure based on channel separation."""
    if not all_experiment_data:
        raise ValueError("No data provided for histogram.")

    all_statistics = {
        'min_frequency': [],
        'max_frequency': [],
        'mean_frequency': [],
        'median_frequency': [],
        'stddev_frequency': []
    }

    for experiment_data in all_experiment_data:
        data = np.array(experiment_data)
        unique_values = set(data)
        num_bins = len(unique_values)
        frequencies, bin_edges = np.histogram(data, bins=num_bins)

        # Calculate statistics on the frequencies
        all_statistics['min_frequency'].append(np.min(frequencies))
        all_statistics['max_frequency'].append(np.max(frequencies))
        all_statistics['mean_frequency'].append(np.mean(frequencies))
        all_statistics['median_frequency'].append(np.median(frequencies))
        all_statistics['stddev_frequency'].append(np.std(frequencies))

    # Average out the statistics
    avg_statistics = {key: np.mean(values) for key, values in all_statistics.items()}

    # Print averaged statistics
    print("Averaged Statistics after", experiments, "experiments:")
    print("Average Minimum Frequency:", avg_statistics['min_frequency'])
    print("Average Maximum Frequency:", avg_statistics['max_frequency'])
    print("Average Mean Frequency: {:.2f}".format(avg_statistics['mean_frequency']))
    print("Average Median Frequency:", avg_statistics['median_frequency'])
    print("Average Standard Deviation of Frequencies: {:.2f}".format(avg_statistics['stddev_frequency']))

    # Plotting the histogram of the last experiment for visualization
    plt.figure(figsize=(10, 5))
    plt.hist(data, bins=num_bins, color='blue', alpha=0.7)
    plt.xlabel('Integer Values')
    plt.ylabel('Frequency')
    plt.title('Averaged Histogram of Integer Values from Phase Shifter')
    plt.grid(True)

    # Save plot to PNG file
    filename = f"histogram_cs_{cs}.png"
    plt.savefig(filename, dpi=300)
    plt.close()  # Close the plot explicitly after saving
    print(f"Histogram saved as {filename}")

if __name__ == "__main__":
    # Sets up the transition matrix and phase shifter matrix
    degree, nc, cs, tm, ps, method, num_integers, bit_width, cycles, experiments = setup()
    # Perform experiments
    all_experiment_data = []
    for _ in tqdm(range(experiments)):
        # Generate a random initial state
        initial_state = np.random.randint(0, 2, degree)
        # Simulate for specified number of cycles
        ps_outints = simulate_lfsr_phase_shifter(tm, ps, initial_state, cycles, method, num_integers, bit_width)
        all_experiment_data.append([item for sublist in ps_outints for item in sublist])
    analyze_and_plot_histogram(all_experiment_data, cs, experiments)
