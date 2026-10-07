/**
 * Tshivenḓa Musical, Cultural & Idiomatic Knowledge Base
 *
 * Honors the namesake of VHUNAMBI ("the talent or ability to sing").
 * Contains regional idioms, musical terms, and lyrical phrases.
 */

export interface VendaIdiom {
  phrase: string;
  meaning: string;
  usageContext: 'celebration' | 'reflection' | 'storytelling' | 'hook';
}

export const VENDA_MUSICAL_TERMS = {
  vhunambi: 'The inherent talent, gift, or extraordinary ability to sing and make music',
  ngoma: 'Sacred drum; rhythm of celebration and communion',
  tshikona: 'The national royal reed-flute dance and polyphonic song tradition',
  malende: 'Joyful communal beer dance songs with syncopated clapping and footwork',
  mbila: 'Indigenous lamellophone/thumb piano providing intricate melodic cycles',
  zwilombe: 'Master singers and traditional musical storytellers',
};

export const VENDA_IDIOMS: VendaIdiom[] = [
  {
    phrase: 'Muthu ndi muthu nga vhathu',
    meaning: 'A person is a person through other people (Ubuntu / Vhuthu)',
    usageContext: 'reflection',
  },
  {
    phrase: 'Vhulenda vhu fhirisa tsie',
    meaning: 'Kindness and gentleness travel farther than an army of locusts',
    usageContext: 'storytelling',
  },
  {
    phrase: 'Ri a dakalo vhukuma namusi',
    meaning: 'We are truly overflowing with joy today',
    usageContext: 'celebration',
  },
  {
    phrase: 'Lwendo lu vhavhaho lu fhedza nga dakalo',
    meaning: 'A difficult journey concludes in triumphant celebration',
    usageContext: 'hook',
  },
];
