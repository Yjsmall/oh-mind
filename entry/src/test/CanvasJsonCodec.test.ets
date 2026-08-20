import { describe, it, expect } from '@ohos/hypium';
import {
  CanvasDocument,
  CanvasJsonCodecError,
  CanvasValidationError,
  parseCanvasJson,
  resolveCanvasEdgeFromEnd,
  resolveCanvasEdgeToEnd,
  serializeCanvasJson
} from '@ohos/mind-elixir';

const TEXT_NODE_A: string =
  '{"id":"node-a","type":"text","text":"# A","x":10,"y":20,"width":240,"height":160}';
const TEXT_NODE_B: string =
  '{"id":"node-b","type":"text","text":"B","x":320,"y":20,"width":220,"height":140,"color":"2"}';

function expectCanvasError(json: string, expectedCode: string): void {
  let caught = false;
  let actualCode = '';
  try {
    parseCanvasJson(json);
  } catch (error) {
    caught = true;
    if (error instanceof CanvasValidationError || error instanceof CanvasJsonCodecError) {
      actualCode = error.code;
    }
  }
  expect(caught).assertEqual(true);
  expect(actualCode).assertEqual(expectedCode);
}

export default function canvasJsonCodecTest() {
  describe('canvasJsonCodecTest', () => {
    it('parsesStandardTextNodesEdgesAndCardNoteExtension', 0, () => {
      const json = `{"nodes":[${TEXT_NODE_A},${TEXT_NODE_B}],"edges":[{` +
        '"id":"edge-a-b","fromNode":"node-a","fromSide":"right","fromEnd":"none",' +
        '"toNode":"node-b","toSide":"left","toEnd":"arrow","label":"relates","color":"#112233"}],' +
        '"cardnote":{"schemaVersion":1,"viewport":{"x":12.5,"y":-8.25,"scale":1.25}}}';

      const document = parseCanvasJson(json);

      expect(document.nodes.length).assertEqual(2);
      expect(document.nodes[0].id).assertEqual('node-a');
      expect(document.nodes[1].id).assertEqual('node-b');
      expect(document.nodes[0].text).assertEqual('# A');
      expect(document.edges[0].fromNode).assertEqual('node-a');
      expect(document.edges[0].toNode).assertEqual('node-b');
      expect(document.cardnote?.viewport.scale).assertEqual(1.25);
    });

    it('roundTripsStandardFieldsAndNodeOrder', 0, () => {
      const source = `{"nodes":[${TEXT_NODE_B},${TEXT_NODE_A}],"edges":[{` +
        '"id":"edge-b-a","fromNode":"node-b","toNode":"node-a","label":"before"}]}';
      const first = parseCanvasJson(source);
      const encoded = serializeCanvasJson(first);
      const second = parseCanvasJson(encoded);

      expect(JSON.stringify(second)).assertEqual(JSON.stringify(first));
      expect(second.nodes[0].id).assertEqual('node-b');
      expect(second.nodes[1].id).assertEqual('node-a');
      expect(encoded.includes('"text"')).assertEqual(true);
      expect(encoded.includes('"fromNode"')).assertEqual(true);
      expect(encoded.includes('"toNode"')).assertEqual(true);
      expect(encoded.includes('"markdown"')).assertEqual(false);
      expect(encoded.includes('"zIndex"')).assertEqual(false);
    });

    it('usesStandardEndpointDefaultsWithoutRewritingOptionalFields', 0, () => {
      const document = parseCanvasJson(`{"nodes":[${TEXT_NODE_A},${TEXT_NODE_B}],` +
        '"edges":[{"id":"edge-a-b","fromNode":"node-a","toNode":"node-b"}]}');

      expect(resolveCanvasEdgeFromEnd(document.edges[0])).assertEqual('none');
      expect(resolveCanvasEdgeToEnd(document.edges[0])).assertEqual('arrow');
      const encoded = serializeCanvasJson(document);
      expect(encoded.includes('"fromEnd"')).assertEqual(false);
      expect(encoded.includes('"toEnd"')).assertEqual(false);
    });

    it('defaultsMissingNodeAndEdgeArraysToEmptyArrays', 0, () => {
      const document = parseCanvasJson('{}');

      expect(document.nodes.length).assertEqual(0);
      expect(document.edges.length).assertEqual(0);
      expect(serializeCanvasJson(document)).assertEqual('{"nodes":[],"edges":[]}');
    });

    it('rejectsNullNodeAndEdgeArrays', 0, () => {
      expectCanvasError('{"nodes":null}', 'INVALID_DOCUMENT');
      expectCanvasError('{"edges":null}', 'INVALID_DOCUMENT');
    });

    it('returnsAnIndependentSnapshot', 0, () => {
      const source: CanvasDocument = {
        nodes: [{ id: 'node-a', type: 'text', text: 'A', x: 0, y: 0, width: 200, height: 100 }],
        edges: []
      };
      const parsed = parseCanvasJson(serializeCanvasJson(source));

      expect(parsed === source).assertEqual(false);
      expect(parsed.nodes === source.nodes).assertEqual(false);
      expect(parsed.nodes[0] === source.nodes[0]).assertEqual(false);
    });

    it('rejectsDuplicateNodeIds', 0, () => {
      expectCanvasError(`{"nodes":[${TEXT_NODE_A},${TEXT_NODE_A}]}`, 'DUPLICATE_NODE_ID');
    });

    it('rejectsDuplicateEdgeIds', 0, () => {
      const edge = '{"id":"edge","fromNode":"node-a","toNode":"node-b"}';
      expectCanvasError(`{"nodes":[${TEXT_NODE_A},${TEXT_NODE_B}],"edges":[${edge},${edge}]}`,
        'DUPLICATE_EDGE_ID');
    });

    it('rejectsDanglingEdges', 0, () => {
      expectCanvasError(`{"nodes":[${TEXT_NODE_A}],"edges":[{` +
        '"id":"dangling","fromNode":"node-a","toNode":"missing"}]}', 'DANGLING_EDGE');
    });

    it('rejectsNonIntegerCoordinatesAndNonPositiveSizes', 0, () => {
      expectCanvasError('{"nodes":[{"id":"n","type":"text","text":"N","x":0.5,"y":0,' +
        '"width":200,"height":100}]}', 'INVALID_NODE');
      expectCanvasError('{"nodes":[{"id":"n","type":"text","text":"N","x":0,"y":0,' +
        '"width":0,"height":100}]}', 'INVALID_NODE');
    });

    it('rejectsInvalidSidesAndEndpointShapes', 0, () => {
      expectCanvasError(`{"nodes":[${TEXT_NODE_A},${TEXT_NODE_B}],"edges":[{` +
        '"id":"edge","fromNode":"node-a","fromSide":"center","toNode":"node-b"}]}', 'INVALID_EDGE');
      expectCanvasError(`{"nodes":[${TEXT_NODE_A},${TEXT_NODE_B}],"edges":[{` +
        '"id":"edge","fromNode":"node-a","toNode":"node-b","toEnd":"circle"}]}', 'INVALID_EDGE');
    });

    it('rejectsNonStandardAndPrivateReferenceFields', 0, () => {
      const invalidJson: string[] = [
        '{"nodes":[{"id":"n","type":"text","text":"N","markdown":"N","x":0,"y":0,' +
          '"width":200,"height":100}]}',
        `{"nodes":[${TEXT_NODE_A},${TEXT_NODE_B}],"edges":[{` +
          '"id":"edge","fromNode":"node-a","fromNodeId":"node-a","toNode":"node-b"}]}',
        `{"nodes":[${TEXT_NODE_A},${TEXT_NODE_B}],"edges":[{` +
          '"id":"edge","fromNode":"node-a","toNode":"node-b","direction":"forward"}]}',
        '{"nodes":[{"id":"n","type":"text","text":"N","x":0,"y":0,"width":200,' +
          '"height":100,"zIndex":2}]}',
        '{"cardnote":{"schemaVersion":1,"viewport":{"x":0,"y":0,"scale":1},' +
          '"highlightIds":["highlight-1"]}}'
      ];

      for (let index = 0; index < invalidJson.length; index++) {
        let caught = false;
        try {
          parseCanvasJson(invalidJson[index]);
        } catch (_error) {
          caught = true;
        }
        expect(caught).assertEqual(true);
      }
    });

    it('rejectsUnsupportedStandardNodeTypesExplicitly', 0, () => {
      const unsupportedTypes: string[] = ['file', 'link', 'group'];
      for (let index = 0; index < unsupportedTypes.length; index++) {
        const json = '{"nodes":[{"id":"n","type":"' + unsupportedTypes[index] +
          '","x":0,"y":0,"width":200,"height":100}]}';
        expectCanvasError(json, 'UNSUPPORTED_NODE_TYPE');
      }
    });

    it('rejectsInvalidCardNoteViewportAndMalformedJson', 0, () => {
      expectCanvasError('{"cardnote":{"schemaVersion":1,"viewport":{"x":0,"y":0,"scale":0}}}',
        'INVALID_CARDNOTE_EXTENSION');
      expectCanvasError('{"nodes":[', 'INVALID_JSON');
    });
  });
}
