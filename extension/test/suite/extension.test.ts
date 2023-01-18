import * as assert from 'assert';
import * as vscode from 'vscode';
suite('Extension Tests', () => {
	
    test('Extension should be present', () => {
        assert.ok(vscode.extensions.getExtension('BIGModelingTools.erdiagram'));
    });
});