# map from species ID to tag model In the case of MERL, we've used the
# larger of the two models Stu suggested.

speciesTagModel = read.csv(
    textConnection("\
id,     group,   english,                                           tagModel
5170,	BIRDS,	 Herring Gull,                                      NTQB-6-2
5280,	BIRDS,	 Great Black-backed Gull,                           NTQB-6-2
2160,	BIRDS,	 Leach's Storm-Petrel,                              NTQB-1
2720,   BIRDS,   Black-crowned Night-Heron,                         NTQB-6-2
4070,   BIRDS,   Black-bellied Plover,                              NTQB-3-2
4100,   BIRDS,   American Golden-Plover,                            NTQB-3-2
4180,   BIRDS,   Semipalmated Plover,                               NTQB-3-2
4190,   BIRDS,   Piping Plover,                                     NTQB-3-2
4630,   BIRDS,   Ruddy Turnstone,                                   NTQB-3-2
4670,   BIRDS,   Red Knot,                                          NTQB-3-2
4680,   BIRDS,   Sanderling,                                        NTQB-3-2
4820,   BIRDS,   Dunlin,                                            NTQB-3-2
40372,  BIRDS,   Dunlin (hudsonia),                                 NTQB-3-2
4800,   BIRDS,   Purple Sandpiper,                                  NTQB-3-2
4750,   BIRDS,   Least Sandpiper,                                   NTQB-3-2
4760,   BIRDS,   White-rumped Sandpiper,                            NTQB-3-2
4690,   BIRDS,   Semipalmated Sandpiper,                            NTQB-3-2
5010,   BIRDS,   Red Phalarope,                                     NTQB-3-2
5570,   BIRDS,   Common Tern,                                       NTQB-4-2
5580,   BIRDS,   Arctic Tern,                                       NTQB-4-2
7100,   BIRDS,   Black-billed Cuckoo,                               NTQB-3-2
7680,   BIRDS,   Northern Saw-whet Owl,                             NTQB-3-2
3580,   BIRDS,   Merlin,                                            NTQB-6-2
13210,  BIRDS,   Loggerhead Shrike,                                 NTQB-3-2
13240,  BIRDS,   White-eyed Vireo,                                  NTQB-2
13460,  BIRDS,   Warbling Vireo,                                    NTQB-2
13490,  BIRDS,   Red-eyed Vireo,                                    NTQB-2
35407,  BIRDS,   Bank Swallow,                                      NTQB-2
14780,  BIRDS,   House Wren,                                        NTQB-2
42067,  BIRDS,   Northern Wheatear,                                 NTQB-3-2
15550,  BIRDS,   Veery,                                             NTQB-3-2
15560,  BIRDS,   Gray-cheeked Thrush,                               NTQB-3-2
15570,  BIRDS,   Bicknell's Thrush,                                 NTQB-3-2
15580,  BIRDS,   Swainson's Thrush,                                 NTQB-3-2
15600,  BIRDS,   Wood Thrush,                                       NTQB-3-2
15970,  BIRDS,   Brown Thrasher,                                    NTQB-3-2
19250,  BIRDS,   Snow Bunting,                                      NTQB-3-2
16930,  BIRDS,   Ovenbird,                                          NTQB-2
16940,  BIRDS,   Northern Waterthrush,                              NTQB-2
16470,  BIRDS,   Orange-crowned Warbler,                            NTQB-2
17130,  BIRDS,   Hooded Warbler,                                    NTQB-2
16890,  BIRDS,   American Redstart,                                 NTQB-2
16580,  BIRDS,   Magnolia Warbler,                                  NTQB-2
16820,  BIRDS,   Blackpoll Warbler,                                 NTQB-2
16600,  BIRDS,   Black-throated Blue Warbler,                       NTQB-2
16801,  BIRDS,   Palm Warbler (Western),                            NTQB-2
16620,  BIRDS,   Yellow-rumped Warbler (Myrtle),                    NTQB-2
16780,  BIRDS,   Prairie Warbler,                                   NTQB-2
17150,  BIRDS,   Canada Warbler,                                    NTQB-2
18800,  BIRDS,   Field Sparrow,                                     NTQB-2
18950,  BIRDS,   Saltmarsh Sparrow,                                 NTQB-2
18961,  BIRDS,   Nelson's/Saltmarsh Sparrow (Sharp-tailed Sparrow), NTQB-2
19000,  BIRDS,   Lincoln's Sparrow,                                 NTQB-2
19030,  BIRDS,   White-throated Sparrow,                            NTQB-3-2
19460,  BIRDS,   Indigo Bunting,                                    NTQB-3-2
19650,  BIRDS,   Rusty Blackbird,                                   NTQB-6-1
20420,  BIRDS,   Pine Siskin,                                       NTQB-2
100190, BATS,    Big Brown Bat,                                     NTQB-2
100230, BATS,    Silver-haired Bat,                                 NTQB-2
100250, BATS,    Eastern Red Bat,                                   NTQB-2
100270, BATS,    Hoary Bat,                                         NTQB-2
100420, BATS,    Eastern Small-footed Bat,                          NTQB-2
100430, BATS,    Little Brown Bat,                                  NTQB-2
100450, BATS,    Northern Long-eared Bat,                           NTQB-2
100460, BATS,    Indiana Bat,                                       NTQB-2
100580, BATS,    Eastern Pipistrelle,                               NTQB-2
252456, INSECTS, Monarch Butterly,                                  NTQB-1-LW
257061, INSECTS, Green Darner,                                      NTQB-1-LW
"
), as.is=TRUE, strip.white=TRUE)
