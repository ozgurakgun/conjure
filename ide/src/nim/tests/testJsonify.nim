import unittest, os
import util/types
import util/jsonify
include util/main

suite "setToJson":
    let validPath = absolutePath("../test/testData/sets/recursive/flagsFlagsFlags")
    echo validPath
    init(validPath)

    test "1":
        let prettyDomains = getPrettyDomainsOfNode(db, "10")
        
        echo prettyDomains[1]
        let json = setToJson(cast[Set](prettyDomains[1]), "10", true)
        echo json

    test "getCollapsedSetChildren":
        let prettyDomains = getPrettyDomainsOfNode(db, "15")
        let kids = getCollapsedSetChildren(cast[Set](prettyDomains[1]))
        check(kids == parseJson("""{"children":[{"name":"s-1","_children":[]},{"name":"s-2","_children":[]}]}"""))

    test "setToTreeView":
        let prettyDomains = getPrettyDomainsOfNode(db, "15")

        let expected = ("""{
        "name": "s",
        "children": [
          {
            "name": "Type",
            "children": [
              {
                "name": "Flags",
                "children": []
              }
            ]
          },
          {
            "name": "Cardinality",
            "children": [
              {
                "name": "int(2)",
                "children": []
              }
            ]
          },
          {
            "name": "Children",
            "children": []
          }
        ]
        }""")
      
        check((%setToTreeView(cast[Set](prettyDomains[1]))) == parseJson(expected))
        
    test "domainsToJson":
        let prettyDomains = getPrettyDomainsOfNode(db, "15")
        let json = domainsToJson(prettyDomains)
        let expected = """{
        "name": "Items",
        "children": [
          {
            "name": "Domain Variables",
            "children": [
              {
                "name": "y",
                "children": [
                  {
                    "name": "int(1)",
                    "children": []
                  }
                ]
              },
              {
                "name": "s",
                "children": [
                  {
                    "name": "Type",
                    "children": [
                      {
                        "name": "Flags",
                        "children": []
                      }
                    ]
                  },
                  {
                    "name": "Cardinality",
                    "children": [
                      {
                        "name": "int(2)",
                        "children": []
                      }
                    ]
                  },
                  {
                    "name": "Children",
                    "children": []
                  }
                ]
              },
              {
                "name": "z",
                "children": [
                  {
                    "name": "int(1)",
                    "children": []
                  }
                ]
              },
              {
                "name": "x",
                "children": [
                  {
                    "name": "int(1)",
                    "children": []
                  }
                ]
              }
            ]
          },
          {
            "name": "Expressions",
            "children": []
          },
          {
            "name": "Changed Expressions",
            "children": []
          }
        ]
        }"""

        check(json == parseJson(expected))            

# suite "":
#     let validPath = absolutePath("../test/testData/sets/recursive/markerMarkerMarker")
#     echo validPath
#     init(validPath)
        # echo pretty2.pretty()
