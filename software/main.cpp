#include <iostream>
#include <random>
#include "cgp_core.hpp" // tam zainkludowane cgp_types.hpp
#include <iomanip>

std::mt19937 rng;

constexpr size_t GENERATIONS = 1000000;
constexpr size_t  SPAN = 10000;// co ile zaakceptowanych mutacji raportowanie
constexpr size_t LAMBDA = 4;// (1+4)-ES optymalne dla CGP (Julian Miller)

int main(int argc, char* argv[]) {

	FaultMask fault; // domyslen wartosci struct FaultMask to brak uszkodzen

	if (argc == 4) {
		try {
			int arg_lut  = std::stoi(argv[1]);
			int arg_port = std::stoi(argv[2]);
			int arg_type = std::stoi(argv[3]);

			if (arg_lut >= 0 && arg_lut < static_cast<int>(NUM_NODES)) {
				fault.target_lut = static_cast<int8_t>(arg_lut);
				fault.port = static_cast<FaultPort>(arg_port);
				fault.type = static_cast<FaultType>(arg_type);

				std::cout << "Tryb ewolucji od ziarna z wprowadzona awaria:\n";
				std::cout << "  -> LUT:  " << static_cast<int>(fault.target_lut) << "\n";
				std::cout << "  -> PORT: " << static_cast<int>(fault.port) << "\n";
				std::cout << "  -> TYP:  " << (arg_type == 0 ? "zwarcie do masy" : "zwarcie do zasilania") << "\n\n";
			} else {
				std::cerr << "[BLAD] Podany indeks LUT poza zakresem (0-29).\n";
				return 1;
			}
		} catch (const std::exception& e) {
			std::cerr << "[BLAD] Argumenty musza byc liczbami calkowitymi.\n";
			std::cerr << "Uzycie: ./sim <LUT_ID> <PORT_ID> <FAULT_TYPE>\n";
			return 1;
		}
	} else if (argc != 1) {
		std::cerr << "Uzycie: ./sim [LUT_ID PORT_ID FAULT_TYPE]\n";
		std::cerr << "Przyklad: ./sim 12 4 0  (LUT 12, OUT, SA0)\n";
		return 1;
	} else {
		std::cout << "Tryb ewolucji od ziarna bez awarii.\n\n";
	}


	//std::random_device rd;
	//rng.seed(rd);
	// inicjalizacja generatora pseudolosowego stala wartoscia - do celow testowych
	rng.seed(31);

	std::cout << "===============================================================\n";
	std::cout << "INICJALIZACJA EWOLUCJI SPRZETOWEJ (1+" << LAMBDA << ")-ES\n";
	std::cout << "===============================================================\n";

	std::cout << "[1/4] Generowanie ziarna\n";

	Individual alpha = create_seed();
	FaultMask no_fault; // domyslen wartosci struct FaultMask to brak uszkodzen
	int fitness = evaluate_fitness(alpha, no_fault);

	std::cout << "	-> Wynik ziarna: " << fitness << " / 24\n";

	if (fitness != 24) {
		std::cout << "	-> [BŁAD] Ziarno nie spelnia zalozen.\n";
		return 1;
	}

	Individual parent = alpha;

	// cena rodzica w warunkach uszkodzenia
	parent.fitness = evaluate_fitness(parent, fault);

	if (fault.is_active()) {
		std::cout << "   	-> Wprowadzenie awarii do ziarna. Fitness spada do: " << parent.fitness << " / 24\n";
	}


	size_t mutations_accepted = 0;

	std::cout << "\n\n[2/4] Uruchomienie petli ewolucyjnej (" << GENERATIONS << " pokolen)\n";

	size_t actual_generations = GENERATIONS;

	for (size_t g = 1; g <= GENERATIONS; ++g) {

		Individual best_child = parent;
		best_child.fitness = -1; // inicjalizacja wartoscia straznicza

		// generowanie potomkow (Lambda)
		for (size_t l = 0; l < LAMBDA; ++l) {
			Individual child = mutate(parent);
			child.fitness = evaluate_fitness(child, fault);

			if (child.fitness > best_child.fitness) {
				best_child = child;
			}
		}

		// porownanie z rodzicem - dryf neutralny (potomek o tym samym fitnes juz zastepuje rodzica)
		if (best_child.fitness >= parent.fitness) {
			parent = best_child;
			mutations_accepted++;
			//raportowanie co SPAN zaakceptowanych mutacji
			if (mutations_accepted % SPAN == 0) {
				std::cout << "Generacja: " << std::setw(8) << g
						  << " | Dryf neutralny: " << std::setw(6) << mutations_accepted
						  << " | Wynik na tym etapie: " << parent.fitness << "/24\n";
			}
		}

		if (fault.is_active() && parent.fitness == 24) {
			std::cout << "\n[SUKCES] Uklad odzyskal pelna sprawnosc 24/24\n";
			std::cout << "-> Wymagalo to " << g << " generacji ewolucyjnych.\n";
			actual_generations = g;
			break;
		}
	}

	std::cout << "\n[3/4] Zakonczono ewaluacje\n";
	std::cout << "Laczna liczba pokolen: " << actual_generations << "\n";
	std::cout << "Akceptowalne przesuniecia struktury (Dryf): " << mutations_accepted << "\n";

	std::string filename_seed = "./hardware/seed.v";
	std::string filename_mutant = "./hardware/mutant.v";
	std::cout << "[4/4] Kompilacja RTL (Register-Transfer Level)\n";

	generateVerilog(alpha, filename_seed, no_fault);
	generateVerilog(parent, filename_mutant, fault);

	std::cout << "==============================================================\n";
	std::cout << "ZAKOŃCZONO. Netlisty zapisane do plikow:\n";
	std::cout << "	" << filename_seed << "\n";
	std::cout << "	" << filename_mutant << "\n";
	std::cout << "==============================================================\n";

	return 0;
}


