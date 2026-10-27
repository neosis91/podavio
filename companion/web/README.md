# Web

This project was generated using [Angular CLI](https://github.com/angular/angular-cli) version 22.2.4.

## Lancer

La page et le relais tournent ensemble. Depuis `companion/web` :

```bash
npm install
npm run build
cd ../server
npm install
npm start
```

Ouvrir http://127.0.0.1:8787. `npm install` n’est utile que la première fois. Après une modification de la page, relancer `npm run build` ici, puis `npm start` dans `companion/server`.

## Code scaffolding

Angular CLI includes powerful code scaffolding tools. To generate a new component, run:

```bash
ng generate component component-name
```

For a complete list of available schematics (such as `components`, `directives`, or `pipes`), run:

```bash
ng generate --help
```

## Building

To build the project run:

```bash
ng build
```

This will compile your project and store the build artifacts in the `dist/` directory. By default, the production build optimizes your application for performance and speed.

## Additional Resources

For more information on using the Angular CLI, including detailed command references, visit the [Angular CLI Overview and Command Reference](https://angular.dev/tools/cli) page.
