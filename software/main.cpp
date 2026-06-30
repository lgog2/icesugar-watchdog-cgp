#include <iostream>
#include <random>
#include "cgp_core.hpp" // tam zainkludowane cgp_types.hpp

std::mt19937 rng;

int main() {
	// inicjalizacja generatora pseudolosowego
	rng.seed(42);

	std::cout << "===============================================================\n";
	std::cout << "WERYFIKACJA ZIARNA\n";
	std::cout << "===============================================================\n";


	std::cout << "[1/3] Generowanie ziarna\n";
	Individual alpha = create_seed();

	std::cout << "[2/3] Ewaluacja\n";

	FaultMask no_fault; // domyslen wartosci struct FaultMask to brak uszkodzen

	int fitness = evaluate_fitness(alpha, no_fault);

	std::cout << "	-> Wynik: " << fitness << " / 24\n";

	if (fitness == 24) {
		std::cout << "	-> [SUKCES] Stan wyjsc w 100% zbiezny z zalozonym dla kazdej kombinacji wejsc.\n";
	} else {
		std::cout << "	-> [BŁAD] .\n";
		std::cout << "	-> Generowanie plku verilog wstrzymane.\n";
		return 1;
	}

	std::string filename = "./hardware/seed.v";
	std::cout << "[3/3] Kompilacja RTL (Register-Transfer Level)\n";

	generateVerilog(alpha, filename);

	std::cout << "==============================================================\n";
	std::cout << "ZAKOŃCZONO. Netlista zapisana do pliku: " << filename << "\n";
	std::cout << "==============================================================\n";

	return 0;
}
