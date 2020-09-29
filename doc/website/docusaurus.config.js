module.exports = {
  title: 'dartros',
  tagline: 'ROS (Robot Operating System) for Dartlang',
  url: 'https://timwhiting.github.io/',
  baseUrl: '/dartros/',
  onBrokenLinks: 'throw',
  favicon: 'img/icon.ico',
  organizationName: 'TimWhiting', // Usually your GitHub org/user name.
  projectName: 'dartros', // Usually your repo name.
  themeConfig: {
    colorMode: {
      defaultMode: 'dark',
    },
    navbar: {
      title: 'dartros',
      logo: {
        alt: 'A robot',
        src: 'img/icon.svg',
      },
      items: [
        {
          to: 'docs/home',
          activeBasePath: 'docs',
          label: 'Docs',
          position: 'left',
        },
        { to: 'blog', label: 'Blog', position: 'left' },
        {
          href: 'https://github.com/TimWhiting/dartros',
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Docs',
          items: [
            {
              label: 'home',
              to: 'docs/home',
              activeBasePath: 'docs',
            },
          ],
        },
        {
          title: 'ROS Community',
          items: [
            {
              label: 'Stack Overflow',
              href: 'https://stackoverflow.com/questions/tagged/ros',
            },
          ],
        },
        {
          title: 'More',
          items: [
            {
              label: 'Blog',
              to: 'blog',
            },
            {
              label: 'GitHub',
              href: 'https://github.com/TimWhiting/dartros',
            },
          ],
        },
        {
          title: 'Credits',
          items: [
            {
              label: 'Icon: "Robot by Rutmer Zijlstra from the Noun Project"',
              href: 'https://thenounproject.com',
            },
          ],
        },
      ],
      copyright: `Copyright © ${new Date().getFullYear()} Tim Whiting. Built with Docusaurus.`,
    },
  },
  presets: [
    [
      '@docusaurus/preset-classic',
      {
        docs: {
          sidebarPath: require.resolve('./sidebars.js'),
          // Please change this to your repo.
          editUrl: 'https://github.com/TimWhiting/dartros/edit/master/docs/website/',
        },
        blog: {
          showReadingTime: true,
          // Please change this to your repo.
          editUrl: 'https://github.com/TimWhiting/dartros/edit/master/docs/website/blog/',
        },
        theme: {
          customCss: require.resolve('./src/css/custom.css'),
        },
      },
    ],
  ],
};
