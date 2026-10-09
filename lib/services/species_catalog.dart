class SpeciesCatalog {
  SpeciesCatalog._();

  static const Map<String, List<String>> _countrySpecies = {
    'Sénégal': [
      'Acacia nilotica', 'Acacia senegal', 'Acacia seyal',
      'Acacia tortilis', 'Adansonia digitata', 'Anacardium occidentale',
      'Anogeissus leiocarpus', 'Azadirachta indica',
      'Balanites aegyptiaca', 'Bauhinia rufescens', 'Bombax costatum',
      'Borassus aethiopum', 'Boscia senegalensis', 'Calotropis procera',
      'Cassia sieberiana', 'Ceiba pentandra', 'Combretum glutinosum',
      'Combretum micranthum', 'Commiphora africana', 'Cordyla pinnata',
      'Daniellia oliveri', 'Detarium senegalense',
      'Dichrostachys cinerea', 'Diospyros mespiliformis',
      'Faidherbia albida', 'Feretia apodanthera', 'Guiera senegalensis',
      'Hyphaene thebaica', 'Lannea acida', 'Mangifera indica',
      'Mitragyna inermis', 'Moringa oleifera', 'Parkia biglobosa',
      'Piliostigma reticulatum', 'Prosopis africana', 'Prosopis juliflora',
      'Pterocarpus erinaceus', 'Sclerocarya birrea', 'Sterculia setigera',
      'Tamarindus indica', 'Terminalia macroptera',
      'Ziziphus mauritiana', 'Ziziphus mucronata',
    ],
    'Kenya': [
      'Vachellia tortilis',
      'Senegalia senegal',
      'Vachellia seyal',
      'Croton megalocarpus',
      'Grevillea robusta',
      'Cordia africana',
      'Olea europaea subsp. cuspidata',
    ],
    'Ghana': [
      'Vitellaria paradoxa',
      'Parkia biglobosa',
      'Milicia excelsa',
      'Daniellia oliveri',
      'Pterocarpus erinaceus',
      'Khaya senegalensis',
      'Ceiba pentandra',
    ],
    'Cameroun': [
      'Triplochiton scleroxylon',
      'Terminalia superba',
      'Lophira alata',
      'Milicia excelsa',
      'Entandrophragma cylindricum',
      'Pycnanthus angolensis',
      'Baillonella toxisperma',
    ],
  };

  static List<String> forCountry(String country) {
    final normalized = country.trim().toLowerCase();
    final match = _countrySpecies.entries.where(
      (entry) => entry.key.toLowerCase() == normalized,
    );
    final values = match.isEmpty ? <String>[] : List<String>.from(match.first.value);
    values.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values;
  }

  static List<String> mergeWithCustom(
    String country,
    Iterable<String> custom,
  ) {
    final values = <String>{...forCountry(country), ...custom}
        .where((value) => value.trim().isNotEmpty)
        .toList();
    values.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values;
  }
}
